{#
    Incremental: window metrics (rolling averages, z-scores, cumulative spend, percentiles) are
    computed over the full history, but on incremental runs only transactions newer than what's
    already in the table are inserted. Rows are therefore "as of when they were loaded".
#}
{{
    config(
        materialized='incremental',
        unique_key='transaction_sk',
        incremental_strategy='delete+insert',
        on_schema_change='append_new_columns'
    )
}}

with transactions as (
    select
        transaction_id,
        account_id,
        merchant_id,
        amount_usd,
        transaction_date,
        transaction_year,
        transaction_month,
        transaction_quarter,
        transaction_dayofweek,
        transaction_size,
        time_of_day,
        day_type,
        is_holiday
    from {{ ref('stg_transactions') }}
),

accounts as (
    select
        account_id,
        customer_id,
        account_type,
        balance_usd as account_balance
    from {{ ref('stg_accounts') }}
),

customers as (
    select
        customer_id,
        first_name,
        last_name,
        credit_score,
        credit_rating,
        customer_tier
    from {{ ref('stg_customers') }}
),

merchants as (
    select
        merchant_id,
        merchant_name,
        city as merchant_city
    from {{ ref('stg_merchants') }}
),

percentile_values as (
    select
        {{ percentile('amount_usd', 0.75) }} as transaction_75th_percentile,
        {{ percentile('amount_usd', 0.95) }} as transaction_95th_percentile,
        {{ percentile('amount_usd', 0.99) }} as transaction_99th_percentile
    from transactions
),

enriched as (
    select
        {{ generate_surrogate_key(['t.transaction_id', 'a.customer_id']) }} as transaction_sk,
        t.transaction_id,
        t.account_id,
        a.customer_id,
        a.account_type,
        a.account_balance as pre_transaction_balance,
        a.account_balance - t.amount_usd as post_transaction_balance,
        t.merchant_id,
        m.merchant_name,
        m.merchant_city,
        c.first_name || ' ' || c.last_name as customer_name,
        c.credit_score,
        c.credit_rating,
        c.customer_tier,
        t.amount_usd,
        t.transaction_date,
        t.transaction_year,
        t.transaction_month,
        t.transaction_quarter,
        t.transaction_dayofweek,
        t.transaction_size,
        t.time_of_day,
        t.day_type,
        t.is_holiday,
        avg(t.amount_usd) over (
            partition by a.customer_id order by t.transaction_date
            rows between 7 preceding and current row
        ) as rolling_7day_avg,
        avg(t.amount_usd) over (
            partition by a.customer_id order by t.transaction_date
            rows between 30 preceding and current row
        ) as rolling_30day_avg,
        p.transaction_95th_percentile,
        p.transaction_99th_percentile,
        p.transaction_75th_percentile,
        (t.amount_usd - avg(t.amount_usd) over (partition by a.customer_id))
            / nullif(stddev(t.amount_usd) over (partition by a.customer_id), 0) as transaction_z_score,
        sum(t.amount_usd) over (
            partition by a.customer_id order by t.transaction_date
            rows unbounded preceding
        ) as cumulative_spend,
        {{ date_diff(
            'lag(t.transaction_date) over (partition by a.customer_id order by t.transaction_date)',
            't.transaction_date',
            'hour'
        ) }} as hours_since_last_transaction
    from transactions t
    left join accounts a on t.account_id = a.account_id
    left join customers c on a.customer_id = c.customer_id
    left join merchants m on t.merchant_id = m.merchant_id
    cross join percentile_values p
)

select
    *,
    case
        when abs(transaction_z_score) > 3 then 'Anomaly'
        when abs(transaction_z_score) > 2 then 'Suspicious'
        else 'Normal'
    end as transaction_risk_flag,
    case
        when amount_usd > transaction_95th_percentile then 'High Value'
        when amount_usd > transaction_75th_percentile then 'Above Average'
        else 'Normal'
    end as value_category
from enriched
{% if is_incremental() %}
where transaction_date > (select coalesce(max(transaction_date), timestamp '1900-01-01') from {{ this }})
{% endif %}
