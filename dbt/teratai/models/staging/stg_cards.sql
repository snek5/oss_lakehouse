with source as (
    select * from {{ ref('raw_cards') }}
),

typed as (
    select
        card_id,
        account_id,
        card_type,
        {{ safe_timestamp('expiration_date') }} as expiration_date
    from source
)

select
    card_id,
    account_id,
    card_type,
    expiration_date,
    cast(expiration_date as date) as expiration_date_only,
    coalesce(expiration_date < {{ now_ts() }}, false) as is_expired,
    {{ date_diff(now_ts(), 'expiration_date', 'month') }} as months_until_expiry,
    year(expiration_date) as expiry_year,
    month(expiration_date) as expiry_month
from typed
