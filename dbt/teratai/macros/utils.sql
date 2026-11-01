-- Use custom schema names as-is (raw, staging, marts, ...) instead of "<target>_<custom>".
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}

-- Glob for a table's CSV files in the CephFS landing zone.
{% macro landing_glob(table_name) -%}
    {{ env_var('LANDING_PATH', '/lakehouse/landing') }}/{{ table_name }}/*.csv
{%- endmacro %}

-- Read every CSV for a table from the landing zone as text; staging does the typing.
{% macro read_landing_csv(table_name) %}
    select
        * exclude (filename),
        filename as _source_file,
        current_timestamp as _loaded_at
    from read_csv(
        '{{ landing_glob(table_name) }}',
        header = true,
        all_varchar = true,
        union_by_name = true,
        filename = true
    )
{% endmacro %}

-- Current time as a plain TIMESTAMP (DuckDB's current_timestamp is TIMESTAMPTZ).
{% macro now_ts() -%}
    cast(current_timestamp as timestamp)
{%- endmacro %}

{% macro safe_decimal(column_name, precision=15, scale=2) -%}
    try_cast({{ column_name }} as decimal({{ precision }}, {{ scale }}))
{%- endmacro %}

{% macro safe_timestamp(column_name) -%}
    try_cast({{ column_name }} as timestamp)
{%- endmacro %}

{% macro date_diff(date1, date2, unit='day') -%}
    date_diff('{{ unit }}', {{ date1 }}, {{ date2 }})
{%- endmacro %}

{% macro age_years(date_column) -%}
    floor(date_diff('day', {{ date_column }}, {{ now_ts() }}) / 365.25)
{%- endmacro %}
