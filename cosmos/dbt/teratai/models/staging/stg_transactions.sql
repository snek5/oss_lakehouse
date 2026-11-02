with source as (
    select * from {{ source('raw', 'transactions') }}
),

renamed as (
    select
        transaction_id,
        account_id,
        merchant_id,
        {{ safe_decimal('amount_usd', 15, 2) }} as amount_usd,
        {{ safe_timestamp('transaction_date') }} as transaction_date,
        date({{ safe_timestamp('transaction_date') }}) as transaction_date_only,
        time({{ safe_timestamp('transaction_date') }}) as transaction_time,
        year({{ safe_timestamp('transaction_date') }}) as transaction_year,
        month({{ safe_timestamp('transaction_date') }}) as transaction_month,
        quarter({{ safe_timestamp('transaction_date') }}) as transaction_quarter,
        day({{ safe_timestamp('transaction_date') }}) as transaction_day,
        hour({{ safe_timestamp('transaction_date') }}) as transaction_hour,
        dayofweek({{ safe_timestamp('transaction_date') }}) as transaction_dayofweek,
        -- Time of day categorization
        case 
            when hour({{ safe_timestamp('transaction_date') }}) between 6 and 11 then 'Morning'
            when hour({{ safe_timestamp('transaction_date') }}) between 12 and 17 then 'Afternoon'
            when hour({{ safe_timestamp('transaction_date') }}) between 18 and 23 then 'Evening'
            else 'Night'
        end as time_of_day,
        -- Transaction size categories
        case 
            when {{ safe_decimal('amount_usd', 15, 2) }} >= 10000 then 'High Value'
            when {{ safe_decimal('amount_usd', 15, 2) }} >= 1000 then 'Medium Value'
            when {{ safe_decimal('amount_usd', 15, 2) }} >= 100 then 'Low Value'
            else 'Micro'
        end as transaction_size,
        -- Weekday vs Weekend
        case 
            when dayofweek({{ safe_timestamp('transaction_date') }}) in (6, 7) then 'Weekend'
            else 'Weekday'
        end as day_type,
        -- Is holiday (simplified - you can expand with actual holiday calendar)
        case 
            when month({{ safe_timestamp('transaction_date') }}) = 12 
                and day({{ safe_timestamp('transaction_date') }}) = 25 then true
            when month({{ safe_timestamp('transaction_date') }}) = 1 
                and day({{ safe_timestamp('transaction_date') }}) = 1 then true
            else false
        end as is_holiday
    from source
)

select * from renamed