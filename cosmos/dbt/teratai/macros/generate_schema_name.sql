{#
  Use a model's custom schema as-is (e.g. `marts`, `analytics`) instead of
  dbt's default `<target_schema>_<custom_schema>` (which gave `staging_marts`).
  Models without a custom schema go to the target schema from profiles.yml.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
