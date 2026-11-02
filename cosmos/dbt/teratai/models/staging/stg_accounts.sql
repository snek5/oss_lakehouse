with source as (
    select * from {{ source('raw', 'accounts') }}
),

renamed as (
    select
        account_id,
        customer_id,
        account_type,
        -- Cast balance to decimal/numeric
        cast(balance_usd as decimal(15,2)) as balance_usd,
        -- Cast timestamp to proper datetime
        cast(open_date as timestamp) as open_date,
        -- Extract date parts for analysis
        date(cast(open_date as timestamp)) as open_date_only,
        year(cast(open_date as timestamp)) as open_year,
        month(cast(open_date as timestamp)) as open_month,
        quarter(cast(open_date as timestamp)) as open_quarter
    from source
)

select * from renamed