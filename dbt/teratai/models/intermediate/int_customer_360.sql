with customers as (
    select
        customer_id,
        first_name,
        last_name,
        email_masked,
        city as customer_city,
        credit_score,
        credit_rating,
        customer_tier,
        created_at,
        customer_age_years
    from {{ ref('stg_customers') }}
),

accounts as (
    select
        customer_id,
        count(account_id) as total_accounts,
        sum(balance_usd) as total_balance_usd,
        avg(balance_usd) as avg_account_balance,
        max(balance_usd) as max_account_balance,
        min(balance_usd) as min_account_balance,
        string_agg(distinct account_type, ', ' order by account_type) as account_types
    from {{ ref('stg_accounts') }}
    group by 1
),

loans as (
    select
        customer_id,
        count(loan_id) as total_loans,
        sum(loan_amount) as total_loan_amount,
        avg(interest_rate) as avg_interest_rate,
        max(loan_amount) as max_loan_amount
    from {{ ref('stg_loans') }}
    where loan_status != 'Completed'
    group by 1
),

cards as (
    select
        a.customer_id,
        count(c.card_id) as total_cards,
        count(case when c.card_type = 'Credit' then 1 end) as credit_cards,
        count(case when c.card_type = 'Debit' then 1 end) as debit_cards,
        count(case when c.is_expired then 1 end) as expired_cards,
        count(case when c.months_until_expiry <= 3 and not c.is_expired then 1 end) as cards_expiring_soon
    from {{ ref('stg_cards') }} c
    left join {{ ref('stg_accounts') }} a on c.account_id = a.account_id
    where c.card_id is not null
    group by 1
),

customer_scoring as (
    select
        customer_id,
        {{ percentile('total_balance_usd', 0.9) }} over () as balance_90th_percentile,
        rank() over (order by total_balance_usd desc) as balance_rank,
        -- quintile 5 = wealthiest 20%
        ntile(5) over (order by total_balance_usd asc) as wealth_quintile
    from accounts
)

select
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email_masked,
    c.customer_city,
    c.credit_score,
    c.credit_rating,
    c.customer_tier,
    c.customer_age_years,
    c.created_at,
    -- accounts
    coalesce(a.total_accounts, 0) as total_accounts,
    coalesce(a.total_balance_usd, 0) as total_balance_usd,
    coalesce(a.avg_account_balance, 0) as avg_account_balance,
    a.account_types,
    -- loans
    coalesce(l.total_loans, 0) as total_loans,
    coalesce(l.total_loan_amount, 0) as total_loan_amount,
    coalesce(l.avg_interest_rate, 0) as avg_interest_rate,
    -- cards
    coalesce(crd.total_cards, 0) as total_cards,
    coalesce(crd.credit_cards, 0) as credit_cards,
    coalesce(crd.debit_cards, 0) as debit_cards,
    coalesce(crd.expired_cards, 0) as expired_cards,
    coalesce(crd.cards_expiring_soon, 0) as cards_expiring_soon,
    -- derived
    coalesce(a.total_balance_usd, 0) - coalesce(l.total_loan_amount, 0) as net_worth,
    round(coalesce(l.total_loan_amount, 0) / nullif(coalesce(a.total_balance_usd, 0), 0), 2) as debt_to_asset_ratio,
    cs.balance_90th_percentile,
    cs.balance_rank,
    cs.wealth_quintile,
    {{ generate_surrogate_key(['c.customer_id', 'c.created_at']) }} as customer_sk,
    c.first_name || '~' || c.last_name || '~' || c.email_masked as customer_business_key,
    case
        when coalesce(a.total_balance_usd, 0) > coalesce(l.total_loan_amount, 0) * 1.5 then 'Excellent'
        when coalesce(a.total_balance_usd, 0) > coalesce(l.total_loan_amount, 0) then 'Good'
        when coalesce(a.total_balance_usd, 0) > coalesce(l.total_loan_amount, 0) * 0.5 then 'Fair'
        else 'Needs Attention'
    end as financial_health_status
from customers c
left join accounts a on c.customer_id = a.customer_id
left join loans l on c.customer_id = l.customer_id
left join cards crd on c.customer_id = crd.customer_id
left join customer_scoring cs on c.customer_id = cs.customer_id
