{{
    config(
        materialized='view',
        schema='analytics',
        tags=['analytics', 'customer_segmentation']
    )
}}

with customers as (
    select * from {{ ref('dim_customers') }}
),

-- Segment metrics using standard SQL
segment_metrics as (
    select
        customer_segment,
        count(customer_id) as customer_count,
        sum(total_balance_usd) as total_portfolio_value,
        avg(total_balance_usd) as avg_balance,
        sum(net_worth) as total_net_worth,
        avg(credit_score) as avg_credit_score,
        percentile_cont(0.5) within group (order by total_balance_usd) as median_balance,
        percentile_cont(0.5) within group (order by net_worth) as median_net_worth,
        count(case when financial_health_status = 'Excellent' then 1 end) as healthy_customers,
        count(case when financial_health_status = 'Needs Attention' then 1 end) as at_risk_customers
    from customers
    where customer_segment is not null
    group by 1
)

select
    sm.customer_segment,
    sm.customer_count,
    sm.total_portfolio_value,
    sm.avg_balance,
    sm.total_net_worth,
    sm.avg_credit_score,
    sm.median_balance,
    sm.median_net_worth,
    sm.healthy_customers,
    sm.at_risk_customers,
    round((sm.healthy_customers / nullif(sm.customer_count, 0)) * 100, 2) as health_percentage,
    round((sm.at_risk_customers / nullif(sm.customer_count, 0)) * 100, 2) as risk_percentage,
    -- Portfolio concentration
    round((sm.total_portfolio_value / nullif(
        sum(sm.total_portfolio_value) over (),
        0
    )) * 100, 2) as portfolio_concentration
from segment_metrics sm
order by sm.total_portfolio_value desc