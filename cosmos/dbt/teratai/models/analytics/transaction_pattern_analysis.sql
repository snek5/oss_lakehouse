{{
    config(
        materialized='view',
        schema='analytics',
        tags=['analytics', 'transaction_patterns']
    )
}}

with transactions as (
    select * from {{ ref('fct_transactions') }}
),

-- Use macro for time-based aggregation
time_aggregates as (
    select
        transaction_year,
        transaction_month,
        transaction_dayofweek,
        time_of_day,
        day_type,
        is_holiday,
        count(transaction_id) as transaction_count,
        sum(amount_usd) as total_amount,
        avg(amount_usd) as avg_amount,
        {{ percentile('amount_usd', 0.5) }} as median_amount,
        {{ percentile('amount_usd', 0.95) }} as p95_amount,
        count(case when transaction_risk_flag = 'Anomaly' then 1 end) as anomaly_count,
        count(case when transaction_risk_flag = 'Suspicious' then 1 end) as suspicious_count
    from transactions
    group by 1, 2, 3, 4, 5, 6
),

-- Use macro for rolling averages
rolling_metrics as (
    select
        *,
        {{ rolling_window('total_amount', '1', 'transaction_year, transaction_month', 3) }} as rolling_3month_avg,
        {{ rolling_window('transaction_count', '1', 'transaction_year, transaction_month', 3) }} as rolling_3month_volume,
        -- Use macro for trend detection
        case 
            when total_amount > {{ rolling_window('total_amount', '1', 'transaction_year, transaction_month', 3) }} 
            then 'Increasing'
            when total_amount < {{ rolling_window('total_amount', '1', 'transaction_year, transaction_month', 3) }} 
            then 'Decreasing'
            else 'Stable'
        end as trend_direction
    from time_aggregates
)

select
    transaction_year,
    transaction_month,
    transaction_dayofweek,
    time_of_day,
    day_type,
    is_holiday,
    transaction_count,
    total_amount,
    avg_amount,
    median_amount,
    p95_amount,
    anomaly_count,
    suspicious_count,
    round((anomaly_count / nullif(transaction_count, 0)) * 100, 2) as anomaly_rate,
    rolling_3month_avg,
    rolling_3month_volume,
    trend_direction,
    -- Use macro for business insights
    case 
        when anomaly_count > 5 and transaction_count > 100 then 'High Risk Period'
        when anomaly_count > 2 and transaction_count > 50 then 'Elevated Risk'
        else 'Normal Operations'
    end as risk_period_category
from rolling_metrics
order by transaction_year desc, transaction_month desc