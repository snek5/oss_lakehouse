-- lake.raw.loans  <-  $LANDING_PATH/loans/*.csv on CephFS (all columns as text)
{{ config(alias='loans') }}

{{ read_landing_csv('loans') }}
