-- Macro to safely cast to decimal
{% macro safe_decimal(column_name, precision=15, scale=2) %}
    try_cast({{ column_name }} as decimal({{ precision }}, {{ scale }}))
{% endmacro %}

-- Macro to convert to timestamp with error handling
{% macro safe_timestamp(column_name) %}
    try_cast({{ column_name }} as timestamp)
{% endmacro %}

-- Macro for date difference calculation
{% macro date_diff(date1, date2, unit='day') %}
    timestampdiff({{ unit | upper }}, {{ date1 }}, {{ date2 }})
{% endmacro %}

-- Macro to calculate age in years
{% macro age_years(date_column) %}
    floor(timestampdiff(DAY, {{ date_column }}, current_timestamp()) / 365.25)
{% endmacro %}

-- Macro to generate column list for staging
{% macro generate_staging_columns(source_table, exclude=[]) %}
    {% set columns = adapter.get_columns_in_relation(source(source_table)) %}
    {% set cols = [] %}
    {% for column in columns %}
        {% if column.name not in exclude %}
            {% do cols.append(column.name) %}
        {% endif %}
    {% endfor %}
    {{ cols | join(', ') }}
{% endmacro %}