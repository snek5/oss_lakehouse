-- lake.raw.branches  <-  $LANDING_PATH/branches/*.csv on CephFS (all columns as text)
{{ config(alias='branches') }}

{{ read_landing_csv('branches') }}
