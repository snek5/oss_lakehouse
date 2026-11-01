-- lake.raw.merchants  <-  $LANDING_PATH/merchants/*.csv on CephFS (all columns as text)
{{ config(alias='merchants') }}

{{ read_landing_csv('merchants') }}
