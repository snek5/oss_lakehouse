-- lake.raw.cards  <-  $LANDING_PATH/cards/*.csv on CephFS (all columns as text)
{{ config(alias='cards') }}

{{ read_landing_csv('cards') }}
