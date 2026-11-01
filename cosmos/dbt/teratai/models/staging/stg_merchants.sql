with source as (
    select * from {{ source('raw', 'merchants') }}
),

renamed as (
    select
        merchant_id,
        merchant_name,
        city
    from source
)

select * from renamed