with customer_transactions as (
    select
        customer_id,
        count(transaction_id) as total_transactions,
        sum(amount_usd) as total_spend,
        avg(amount_usd) as avg_transaction_value,
        min(transaction_date) as first_transaction,
        max(transaction_date) as last_transaction,
        {{ date_diff('min(transaction_date)', 'max(transaction_date)', 'day') }} as customer_lifetime_days,
        count(distinct merchant_id) as unique_merchants
    from {{ ref('fct_transactions') }}
    where customer_id is not null
    group by 1
),

clv_calculation as (
    select
        customer_id,
        total_transactions,
        total_spend,
        avg_transaction_value,
        customer_lifetime_days,
        unique_merchants,
        round(total_spend * 0.3, 2) as estimated_clv,  -- 30% margin assumption
        round(total_spend / nullif(customer_lifetime_days, 0) * 365, 2) as annualized_value,
        case
            when total_spend * 0.3 > 50000 then 'High Value'
            when total_spend * 0.3 > 20000 then 'Medium Value'
            when total_spend * 0.3 > 5000 then 'Low Value'
            else 'Lowest Value'
        end as clv_tier,
        case
            when total_transactions > 100 and unique_merchants > 20 then 10
            when total_transactions > 50 and unique_merchants > 10 then 7
            when total_transactions > 20 and unique_merchants > 5 then 4
            else 1
        end as engagement_score
    from customer_transactions
)

select
    clv.customer_id,
    c.first_name || ' ' || c.last_name as customer_name,
    c.credit_score,
    c.credit_rating,
    c.customer_tier,
    clv.total_transactions,
    clv.total_spend,
    clv.avg_transaction_value,
    clv.customer_lifetime_days,
    clv.unique_merchants,
    clv.estimated_clv,
    clv.annualized_value,
    clv.clv_tier,
    clv.engagement_score,
    case
        when clv.engagement_score >= 7 and clv.clv_tier in ('Low Value', 'Lowest Value') then 'High Growth Potential'
        when clv.engagement_score >= 4 and clv.clv_tier = 'Medium Value' then 'Upsell Opportunity'
        when clv.engagement_score >= 7 and clv.clv_tier = 'High Value' then 'Premium Retention'
        else 'Monitor'
    end as growth_strategy,
    current_timestamp as analysis_date
from clv_calculation clv
left join {{ ref('stg_customers') }} c on clv.customer_id = c.customer_id
