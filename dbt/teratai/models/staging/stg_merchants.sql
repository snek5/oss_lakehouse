with source as (
    select * from {{ ref('raw_merchants') }}
)

select
    merchant_id,
    merchant_name,
    city
from source
