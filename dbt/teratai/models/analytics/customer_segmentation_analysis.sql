with customers as (
    select * from {{ ref('dim_customers') }}
),

segment_metrics as (
    select
        customer_segment,
        count(customer_id) as customer_count,
        sum(total_balance_usd) as total_portfolio_value,
        avg(total_balance_usd) as avg_balance,
        sum(net_worth) as total_net_worth,
        avg(credit_score) as avg_credit_score,
        {{ percentile('total_balance_usd', 0.5) }} as median_balance,
        {{ percentile('net_worth', 0.5) }} as median_net_worth,
        count(case when financial_health_status = 'Excellent' then 1 end) as healthy_customers,
        count(case when financial_health_status = 'Needs Attention' then 1 end) as at_risk_customers
    from customers
    where customer_segment is not null
    group by 1
)

select
    customer_segment,
    customer_count,
    total_portfolio_value,
    avg_balance,
    total_net_worth,
    avg_credit_score,
    median_balance,
    median_net_worth,
    healthy_customers,
    at_risk_customers,
    round(healthy_customers / nullif(customer_count, 0) * 100, 2) as health_percentage,
    round(at_risk_customers / nullif(customer_count, 0) * 100, 2) as risk_percentage,
    round(total_portfolio_value / nullif(sum(total_portfolio_value) over (), 0) * 100, 2) as portfolio_concentration
from segment_metrics
