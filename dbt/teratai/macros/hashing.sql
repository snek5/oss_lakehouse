-- Mask PII, keeping the first 3 and last 4 characters.
{% macro mask_pii(column_name) -%}
    case
        when {{ column_name }} is null then null
        else concat(left({{ column_name }}, 3), '********', right({{ column_name }}, 4))
    end
{%- endmacro %}

{% macro hash_column(column_name) -%}
    sha256(cast({{ column_name }} as varchar))
{%- endmacro %}
