with source as (
    select * from {{ ref('raw_transactions') }}
),

typed as (
    select
        transaction_id,
        account_id,
        merchant_id,
        {{ safe_decimal('amount_usd', 15, 2) }} as amount_usd,
        {{ safe_timestamp('transaction_date') }} as transaction_date
    from source
)

select
    transaction_id,
    account_id,
    merchant_id,
    amount_usd,
    transaction_date,
    cast(transaction_date as date) as transaction_date_only,
    cast(transaction_date as time) as transaction_time,
    year(transaction_date) as transaction_year,
    month(transaction_date) as transaction_month,
    quarter(transaction_date) as transaction_quarter,
    day(transaction_date) as transaction_day,
    hour(transaction_date) as transaction_hour,
    -- ISO day of week: 1 = Monday ... 7 = Sunday
    isodow(transaction_date) as transaction_dayofweek,
    case
        when hour(transaction_date) between 6 and 11 then 'Morning'
        when hour(transaction_date) between 12 and 17 then 'Afternoon'
        when hour(transaction_date) between 18 and 23 then 'Evening'
        else 'Night'
    end as time_of_day,
    case
        when amount_usd >= 10000 then 'High Value'
        when amount_usd >= 1000 then 'Medium Value'
        when amount_usd >= 100 then 'Low Value'
        else 'Micro'
    end as transaction_size,
    case when isodow(transaction_date) in (6, 7) then 'Weekend' else 'Weekday' end as day_type,
    -- simplified holiday calendar
    coalesce(
        (month(transaction_date) = 12 and day(transaction_date) = 25)
        or (month(transaction_date) = 1 and day(transaction_date) = 1),
        false
    ) as is_holiday
from typed
