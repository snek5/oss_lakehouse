with source as (
    select * from {{ ref('raw_accounts') }}
),

typed as (
    select
        account_id,
        customer_id,
        account_type,
        {{ safe_decimal('balance_usd', 15, 2) }} as balance_usd,
        {{ safe_timestamp('open_date') }} as open_date
    from source
)

select
    account_id,
    customer_id,
    account_type,
    balance_usd,
    open_date,
    cast(open_date as date) as open_date_only,
    year(open_date) as open_year,
    month(open_date) as open_month,
    quarter(open_date) as open_quarter
from typed
