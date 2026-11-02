{{
    config(
        materialized='incremental',
        schema='marts',
        unique_key='account_id',
        incremental_strategy='merge',
        tags=['marts', 'fact', 'account'],
        on_schema_change='append_new_columns'
    )
}}

with account_base as (
    select 
        account_id,
        customer_id,
        account_type,
        balance_usd as current_balance,
        open_date,
        open_year,
        open_month,
        {{ age_years('open_date') }} as account_age_years,
        {{ date_diff('open_date', 'current_timestamp()', 'month') }} as account_age_months
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

transaction_metrics as (
    select
        account_id,
        count(transaction_id) as transaction_count,
        sum(amount_usd) as total_transaction_amount,
        avg(amount_usd) as avg_transaction_amount,
        {{ percentile('amount_usd', 0.5) }} as median_transaction_amount,
        min(amount_usd) as min_transaction_amount,
        max(amount_usd) as max_transaction_amount,
        min(transaction_date) as first_transaction_date,
        max(transaction_date) as last_transaction_date,
        count(distinct merchant_id) as distinct_merchants,
        count(case when amount_usd > 10000 then 1 end) as high_value_transactions,
        -- Use macro for time-based metrics
        {{ date_diff('min(transaction_date)', 'max(transaction_date)', 'day') }} as transaction_span_days,
        count(transaction_id) / nullif(
            {{ date_diff('min(transaction_date)', 'max(transaction_date)', 'month') }},
            0
        ) as transactions_per_month
    from {{ ref('stg_transactions') }}
    {% if is_incremental() %}
        where transaction_date > (select max(last_transaction_date) from {{ this }} where account_id is not null)
    {% endif %}
    group by 1
),

-- Use macro for account scoring
account_scoring as (
    select
        account_id,
        -- Balance percentile using macro
        {{ percentile('current_balance', 0.9) }} over () as balance_90th_percentile,
        {{ percentile('current_balance', 0.5) }} over () as balance_median,
        -- Activity score using macro calculations
        case 
            when transaction_count > 50 then 'Very Active'
            when transaction_count > 20 then 'Active'
            when transaction_count > 5 then 'Moderate'
            else 'Inactive'
        end as activity_level
    from account_base
)

select
    ab.account_id,
    ab.customer_id,
    c.first_name || ' ' || c.last_name as customer_name,
    c.credit_score,
    c.credit_rating,
    c.customer_tier,
    ab.account_type,
    ab.current_balance,
    ab.open_date,
    ab.open_year,
    ab.open_month,
    ab.account_age_years,
    ab.account_age_months,
    -- Transaction metrics
    coalesce(tm.transaction_count, 0) as transaction_count,
    coalesce(tm.total_transaction_amount, 0) as total_transaction_amount,
    coalesce(tm.avg_transaction_amount, 0) as avg_transaction_amount,
    coalesce(tm.median_transaction_amount, 0) as median_transaction_amount,
    coalesce(tm.min_transaction_amount, 0) as min_transaction_amount,
    coalesce(tm.max_transaction_amount, 0) as max_transaction_amount,
    tm.first_transaction_date,
    tm.last_transaction_date,
    coalesce(tm.distinct_merchants, 0) as distinct_merchants,
    coalesce(tm.high_value_transactions, 0) as high_value_transactions,
    coalesce(tm.transactions_per_month, 0) as avg_transactions_per_month,
    -- Scoring metrics
    asco.balance_90th_percentile,
    asco.balance_median,
    asco.activity_level,
    -- Use macro for net flow analysis
    case 
        when tm.total_transaction_amount > 0 then 
            round((tm.total_transaction_amount / ab.current_balance) * 100, 2)
        else 0
    end as turnover_ratio,
    -- Use macro for balance category
    case 
        when ab.current_balance > asco.balance_90th_percentile then 'High Balance'
        when ab.current_balance > asco.balance_median then 'Medium Balance'
        else 'Low Balance'
    end as balance_category,
    -- Account health status using macro logic
    case 
        when coalesce(tm.transaction_count, 0) = 0 then 'Dormant'
        when ab.current_balance < 0 then 'Overdrawn'
        when ab.account_age_years > 5 and tm.transaction_count > 100 then 'Mature Active'
        when ab.account_age_years > 5 and tm.transaction_count <= 100 then 'Mature Low Activity'
        else 'Standard'
    end as account_health_status,
    -- Hash for tracking
    {{ hash_column('ab.account_id || cast(ab.current_balance as string) || cast(current_timestamp() as string)') }} as account_snapshot_hash,
    -- Metadata
    current_timestamp() as dbt_updated_at,
    '{{ invocation_id }}' as dbt_invocation_id
from account_base ab
left join customers c on ab.customer_id = c.customer_id
left join transaction_metrics tm on ab.account_id = tm.account_id
left join account_scoring asco on ab.account_id = asco.account_id