with source as (
    select * from {{ source('raw', 'branches') }}
),

renamed as (
    select
        branch_id,
        branch_name,
        manager_name,
        -- Handle empty strings as NULL
        nullif(city, '') as city,
        nullif(country, '') as country
    from source
)

select * from renamed