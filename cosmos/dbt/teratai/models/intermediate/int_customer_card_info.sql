{{
    config(
        materialized='view',
        tags=['intermediate', 'customer_cards']
    )
}}

with cards as (
    select 
        card_id,
        account_id,
        card_type,
        expiration_date,
        is_expired,
        months_until_expiry,
        expiration_date_only,
        expiry_year,
        expiry_month
    from {{ ref('stg_cards') }}
),

accounts as (
    select 
        account_id,
        customer_id,
        account_type,
        balance_usd
    from {{ ref('stg_accounts') }}
),

customers as (
    select 
        customer_id,
        first_name,
        last_name,
        email,
        credit_score,
        credit_rating
    from {{ ref('stg_customers') }}
)

select
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email,
    c.credit_score,
    c.credit_rating,
    a.account_id,
    a.account_type,
    a.balance_usd,
    cards.card_id,
    cards.card_type,
    cards.expiration_date,
    cards.is_expired,
    cards.months_until_expiry,
    -- Card status
    case 
        when cards.is_expired = true then 'Expired'
        when cards.months_until_expiry <= 3 then 'Expiring Soon'
        else 'Active'
    end as card_status,
    -- Card age in days
    timestampdiff(DAY, cards.expiration_date, current_timestamp()) as days_since_expiry,
    -- Card type category
    case 
        when cards.card_type = 'Credit' then 'Credit Card'
        when cards.card_type = 'Debit' then 'Debit Card'
        else 'Other'
    end as card_category
from customers c
left join accounts a on c.customer_id = a.customer_id
left join cards on a.account_id = cards.account_id