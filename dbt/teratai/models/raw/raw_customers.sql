-- lake.raw.customers  <-  $LANDING_PATH/customers/*.csv on CephFS (all columns as text)
{{ config(alias='customers') }}

{{ read_landing_csv('customers') }}
