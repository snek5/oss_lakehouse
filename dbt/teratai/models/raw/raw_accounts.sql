-- lake.raw.accounts  <-  $LANDING_PATH/accounts/*.csv on CephFS (all columns as text)
{{ config(alias='accounts') }}

{{ read_landing_csv('accounts') }}
