{{
    config(
        materialized='incremental',
        schema='analytics',
        unique_key='customer_id',
        incremental_strategy='merge',
        tags=['analytics', 'clv_analysis']
    )
}}

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
    {% if is_incremental() %}
        where customer_id in (
            select distinct customer_id 
            from {{ ref('fct_transactions') }}
            where transaction_date > (select max(analysis_date) from {{ this }})
        )
    {% endif %}
    group by 1
),

-- Use macro for CLV calculation
clv_calculation as (
    select
        ct.customer_id,
        ct.total_transactions,
        ct.total_spend,
        ct.avg_transaction_value,
        ct.customer_lifetime_days,
        ct.unique_merchants,
        -- Calculate CLV using macro
        round(ct.total_spend * 0.3, 2) as estimated_clv, -- 30% profit margin
        round(
            (ct.total_spend / nullif(ct.customer_lifetime_days, 0)) * 365,
            2
        ) as annualized_value,
        -- Customer tier based on CLV using macro
        case 
            when round(ct.total_spend * 0.3, 2) > 50000 then 'High Value'
            when round(ct.total_spend * 0.3, 2) > 20000 then 'Medium Value'
            when round(ct.total_spend * 0.3, 2) > 5000 then 'Low Value'
            else 'Lowest Value'
        end as clv_tier,
        -- Use macro for engagement score
        case 
            when ct.total_transactions > 100 and ct.unique_merchants > 20 then 10
            when ct.total_transactions > 50 and ct.unique_merchants > 10 then 7
            when ct.total_transactions > 20 and ct.unique_merchants > 5 then 4
            else 1
        end as engagement_score
    from customer_transactions ct
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
    -- Use macro for growth potential
    case 
        when clv.engagement_score >= 7 and clv.clv_tier in ('Low Value', 'Lowest Value') then 'High Growth Potential'
        when clv.engagement_score >= 4 and clv.clv_tier = 'Medium Value' then 'Upsell Opportunity'
        when clv.engagement_score >= 7 and clv.clv_tier = 'High Value' then 'Premium Retention'
        else 'Monitor'
    end as growth_strategy,
    -- Metadata
    current_timestamp() as analysis_date,
    current_timestamp() as dbt_updated_at
from clv_calculation clv
left join {{ ref('stg_customers') }} c on clv.customer_id = c.customer_id