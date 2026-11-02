-- Macro for sensitive data masking
{% macro mask_pii(column_name) %}
    case 
        when {{ column_name }} is null then null
        else concat(
            left({{ column_name }}, 3),
            '********',
            right({{ column_name }}, 4)
        )
    end
{% endmacro %}

-- Macro to hash sensitive columns
{% macro hash_column(column_name, algorithm='sha256') %}
    {#- Spark has no sha256(); use sha2(x, bits) for the SHA-2 family -#}
    {%- if algorithm in ['sha224', 'sha256', 'sha384', 'sha512'] -%}
    sha2(cast({{ column_name }} as string), {{ algorithm[3:] }})
    {%- else -%}
    {{ algorithm }}(cast({{ column_name }} as string))
    {%- endif -%}
{% endmacro %}