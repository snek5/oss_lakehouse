{#
  Create the raw Iceberg tables that the staging models read from.

  For every table in the `raw` source (models/sources/sources.yml):
    1. a temporary view is created over its CSV folder in the landing bucket
    2. `raw.<table>` is created as an Iceberg table from that view

  Tables that already exist are left alone, so this is cheap to run every time.

  Runs automatically as an on-run-start hook (dbt_project.yml). Can also be run
  on its own, which is what the Airflow DAG does:

      dbt run-operation stage_raw_sources
      dbt run-operation stage_raw_sources --args '{refresh: true}'   # reload all

  Vars:
      refresh_raw: true       reload raw tables from CSV during a normal run
      skip_raw_staging: true  make the on-run-start hook a no-op
#}
{% macro stage_raw_sources(source_name='raw', refresh=none, from_hook=false) %}
  {%- if not execute -%}{{ return('') }}{%- endif -%}
  {%- if from_hook and var('skip_raw_staging', false) -%}{{ return('') }}{%- endif -%}
  {%- set refresh = var('refresh_raw', false) if refresh is none else refresh -%}

  {%- set raw_sources = graph.sources.values() | selectattr('source_name', 'equalto', source_name) | list -%}
  {%- if raw_sources | length == 0 -%}
    {{ log("stage_raw_sources: no tables found for source '" ~ source_name ~ "'", info=true) }}
    {{ return('') }}
  {%- endif -%}

  {%- set schema = raw_sources[0].schema -%}
  {% do run_query('create namespace if not exists ' ~ schema) %}

  {%- set existing = [] -%}
  {%- for row in run_query('show tables in ' ~ schema) -%}
    {% do existing.append(row['tableName'] | lower) %}
  {%- endfor -%}

  {%- for src in raw_sources -%}
    {%- set table = src.identifier or src.name -%}
    {%- set meta = src.get('meta', {}) or {} -%}
    {%- set path = meta.get('landing_path', 's3a://landing/' ~ table ~ '/') -%}

    {%- if refresh or (table | lower) not in existing -%}
      {%- set options = {'header': 'true', 'inferSchema': 'true', 'nullValue': ''} -%}
      {%- do options.update(meta.get('csv_options', {}) or {}) -%}
      {%- set view = '__landing_' ~ table -%}

      {{ log("stage_raw_sources: loading " ~ schema ~ "." ~ table ~ " from " ~ path, info=true) }}

      {% call statement('landing_view_' ~ table) -%}
        create or replace temporary view {{ view }}
        using csv
        options (
          path '{{ path }}'
          {%- for key, value in options.items() %},
          {{ key }} '{{ value | string | lower if value is boolean else value }}'
          {%- endfor %}
        )
      {%- endcall %}

      {% call statement('raw_table_' ~ table) -%}
        create or replace table {{ schema }}.{{ table }}
        using iceberg
        as select *, current_timestamp() as _loaded_at
        from {{ view }}
      {%- endcall %}

      {% do run_query('drop view if exists ' ~ view) %}
    {%- else -%}
      {{ log("stage_raw_sources: " ~ schema ~ "." ~ table ~ " exists, skipping", info=false) }}
    {%- endif -%}
  {%- endfor -%}

  {{ return('') }}
{% endmacro %}
