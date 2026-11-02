-- Macro to compute percentile
{% macro percentile(column_name, percentile_value=0.5) %}
    percentile_cont({{ percentile_value }}) within group (order by {{ column_name }})
{% endmacro %}

-- Macro to calculate customer lifetime value (CLV)
{% macro calculate_clv(customer_id) %}
    with customer_transactions as (
        select 
            customer_id,
            sum(amount_usd) as total_spend,
            count(distinct transaction_id) as transaction_count,
            timestampdiff(DAY, min(transaction_date), max(transaction_date)) as customer_lifetime_days
        from {{ ref('fct_transactions') }}
        where customer_id = {{ customer_id }}
        group by 1
    )
    select 
        total_spend,
        transaction_count,
        customer_lifetime_days,
        total_spend / nullif(customer_lifetime_days, 0) * 365 as annual_value,
        total_spend * 0.3 as estimated_lifetime_value -- Simplified 30% margin assumption
    from customer_transactions
{% endmacro %}

-- Macro for rolling window calculations
{% macro rolling_window(column_name, partition_by, order_by, window_size=30) %}
    avg({{ column_name }}) over (
        partition by {{ partition_by }} 
        order by {{ order_by }} 
        rows between {{ window_size }} preceding and current row
    )
{% endmacro %}