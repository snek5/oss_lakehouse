with source as (
    select * from {{ source('raw', 'cards') }}
),

renamed as (
    select
        card_id,
        account_id,
        card_type,
        cast(expiration_date as timestamp) as expiration_date,
        date(cast(expiration_date as timestamp)) as expiration_date_only,
        -- Calculate if card is expired
        case 
            when cast(expiration_date as timestamp) < current_timestamp() then true
            else false
        end as is_expired,
        -- Calculate months until expiration
        timestampdiff(MONTH, current_timestamp(), cast(expiration_date as timestamp)) as months_until_expiry,
        -- Extract year and month for expiry
        year(cast(expiration_date as timestamp)) as expiry_year,
        month(cast(expiration_date as timestamp)) as expiry_month
    from source
)

select * from renamed