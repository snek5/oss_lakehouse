-- Continuous percentile. Works both as an aggregate and as a window function (`... over ()`).
{% macro percentile(column_name, percentile_value=0.5) -%}
    quantile_cont({{ column_name }}, {{ percentile_value }})
{%- endmacro %}

{% macro rolling_window(column_name, partition_by, order_by, window_size=30) -%}
    avg({{ column_name }}) over (
        partition by {{ partition_by }}
        order by {{ order_by }}
        rows between {{ window_size }} preceding and current row
    )
{%- endmacro %}
