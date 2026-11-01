-- lake.raw.transactions  <-  $LANDING_PATH/transactions/*.csv on CephFS (all columns as text)
{{ config(alias='transactions') }}

{{ read_landing_csv('transactions') }}
