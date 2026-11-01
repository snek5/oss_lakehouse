"""Drop a synthetic banking dataset into the CephFS landing zone (run once to try the stack)."""

import os
from datetime import datetime

from airflow.sdk import dag, task

LANDING_PATH = os.getenv("LANDING_PATH", "/lakehouse/landing")


@dag(
    dag_id="teratai_sample_data",
    schedule=None,
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=["teratai", "sample-data"],
    params={"customers": 500, "transactions": 20000, "seed": 42},
)
def teratai_sample_data():
    @task
    def generate_csvs(params=None) -> dict:
        from teratai_utils.sample_data import generate

        counts = generate(
            LANDING_PATH,
            customers=int(params["customers"]),
            transactions=int(params["transactions"]),
            seed=int(params["seed"]),
        )
        for table, rows in counts.items():
            print(f"{table}: {rows} rows -> {LANDING_PATH}/{table}/")
        return counts

    generate_csvs()


teratai_sample_data()
