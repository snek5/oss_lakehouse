-- md5 surrogate key over a list of column expressions (null-safe). Replaces dbt_utils so the
-- project has no package dependencies.
{% macro generate_surrogate_key(columns) -%}
    md5(concat_ws('|'
        {%- for column in columns %},
        coalesce(cast({{ column }} as varchar), '_dbt_null_')
        {%- endfor %}
    ))
{%- endmacro %}
