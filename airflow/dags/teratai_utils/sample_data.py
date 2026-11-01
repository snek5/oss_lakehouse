"""Generate a small synthetic banking dataset as CSVs in the landing zone.

Layout produced (one folder per source table, which is what the dbt raw layer globs):
    <landing>/customers/customers.csv
    <landing>/accounts/accounts.csv
    ...

Also runnable outside Airflow:
    python airflow/dags/teratai_utils/sample_data.py --out ./landing
"""

from __future__ import annotations

import argparse
import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

FIRST_NAMES = ["Aisyah", "Hakim", "Siti", "Daniel", "Mei Ling", "Arjun", "Nurul", "Wei Jie", "Farah", "Ravi",
               "Amir", "Chloe", "Haziq", "Priya", "Liyana", "Marcus", "Zara", "Irfan", "Hana", "Kumar"]
LAST_NAMES = ["Rahman", "Tan", "Lim", "Abdullah", "Wong", "Nair", "Ismail", "Chen", "Ong", "Hassan",
              "Lee", "Yusof", "Ng", "Pillai", "Ahmad"]
CITIES = [("Bandar Seri Begawan", "Brunei"), ("Kuala Belait", "Brunei"), ("Kota Kinabalu", "Malaysia"),
          ("Kuching", "Malaysia"), ("Kuala Lumpur", "Malaysia"), ("Singapore", "Singapore"),
          ("Jakarta", "Indonesia"), ("Manila", "Philippines")]
MERCHANT_KINDS = ["Mart", "Coffee", "Fuel", "Pharmacy", "Electronics", "Books", "Grocer", "Air", "Hotel", "Diner"]
ACCOUNT_TYPES = ["Savings", "Checking", "Business", "Fixed Deposit"]

TABLES = ["customers", "accounts", "branches", "cards", "loans", "merchants", "transactions"]


def _ts(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def _write(out: Path, table: str, header: list[str], rows: list[list]) -> int:
    folder = out / table
    folder.mkdir(parents=True, exist_ok=True)
    with open(folder / f"{table}.csv", "w", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(header)
        writer.writerows(rows)
    return len(rows)


def generate(out: str | Path, customers: int = 500, transactions: int = 20_000, seed: int = 42) -> dict[str, int]:
    rng = random.Random(seed)
    out = Path(out)
    now = datetime.now().replace(microsecond=0)
    counts: dict[str, int] = {}

    # customers
    cust_rows = []
    for i in range(1, customers + 1):
        first, last = rng.choice(FIRST_NAMES), rng.choice(LAST_NAMES)
        created = now - timedelta(days=rng.randint(30, 10 * 365), seconds=rng.randint(0, 86_399))
        email = f"{first.lower().replace(' ', '')}.{last.lower()}{i}@example.com"
        score = "" if rng.random() < 0.02 else rng.randint(450, 850)  # a few missing scores
        cust_rows.append([f"C{i:05d}", first, last, email, rng.choice(CITIES)[0], score, _ts(created)])
    counts["customers"] = _write(out, "customers",
                                 ["customer_id", "first_name", "last_name", "email", "city", "credit_score", "created_at"],
                                 cust_rows)

    # accounts (1-3 per customer)
    acct_rows, account_ids = [], []
    n = 0
    for c in cust_rows:
        for _ in range(rng.choices([1, 2, 3], weights=[5, 3, 1])[0]):
            n += 1
            acct_id = f"A{n:06d}"
            account_ids.append(acct_id)
            opened = datetime.strptime(c[6], "%Y-%m-%d %H:%M:%S") + timedelta(days=rng.randint(0, 365))
            balance = round(rng.lognormvariate(9, 1.2), 2) * (-1 if rng.random() < 0.02 else 1)
            acct_rows.append([acct_id, c[0], rng.choice(ACCOUNT_TYPES), f"{balance:.2f}", _ts(min(opened, now))])
    counts["accounts"] = _write(out, "accounts",
                                ["account_id", "customer_id", "account_type", "balance_usd", "open_date"], acct_rows)

    # branches
    branch_rows = []
    for i in range(1, 21):
        city, country = rng.choice(CITIES)
        branch_rows.append([f"B{i:03d}", f"{city} Branch {i}", f"{rng.choice(FIRST_NAMES)} {rng.choice(LAST_NAMES)}",
                            city if rng.random() > 0.05 else "", country])
    counts["branches"] = _write(out, "branches", ["branch_id", "branch_name", "manager_name", "city", "country"],
                                branch_rows)

    # cards (~80% of accounts)
    card_rows = []
    for i, acct in enumerate((a for a in account_ids if rng.random() < 0.8), start=1):
        expires = now + timedelta(days=rng.randint(-400, 5 * 365))
        card_rows.append([f"K{i:06d}", acct, rng.choice(["Credit", "Debit"]), expires.strftime("%Y-%m-%d")])
    counts["cards"] = _write(out, "cards", ["card_id", "account_id", "card_type", "expiration_date"], card_rows)

    # loans (~40% of customers)
    loan_rows = []
    for i, c in enumerate((c for c in cust_rows if rng.random() < 0.4), start=1):
        start = now - timedelta(days=rng.randint(10, 7 * 365))
        loan_rows.append([f"L{i:05d}", c[0], f"{rng.randint(2, 400) * 500:.2f}",
                          f"{rng.uniform(2.5, 14.0):.2f}", start.strftime("%Y-%m-%d")])
    counts["loans"] = _write(out, "loans", ["loan_id", "customer_id", "loan_amount", "interest_rate", "start_date"],
                             loan_rows)

    # merchants
    merchant_rows = []
    for i in range(1, 101):
        merchant_rows.append([f"M{i:04d}", f"{rng.choice(LAST_NAMES)} {rng.choice(MERCHANT_KINDS)}",
                              rng.choice(CITIES)[0]])
    counts["merchants"] = _write(out, "merchants", ["merchant_id", "merchant_name", "city"], merchant_rows)

    # transactions over the last 2 years
    txn_rows = []
    for i in range(1, transactions + 1):
        when = now - timedelta(seconds=rng.randint(0, 2 * 365 * 86_400))
        amount = rng.lognormvariate(4.2, 1.3)
        if rng.random() < 0.003:  # sprinkle in some outliers
            amount *= 60
        txn_rows.append([f"T{i:07d}", rng.choice(account_ids), f"M{rng.randint(1, 100):04d}",
                         f"{amount:.2f}", _ts(when)])
    counts["transactions"] = _write(out, "transactions",
                                    ["transaction_id", "account_id", "merchant_id", "amount_usd", "transaction_date"],
                                    txn_rows)
    return counts


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", default="./landing")
    parser.add_argument("--customers", type=int, default=500)
    parser.add_argument("--transactions", type=int, default=20_000)
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()
    for table, rows in generate(args.out, args.customers, args.transactions, args.seed).items():
        print(f"{table:<13} {rows:>7} rows")
