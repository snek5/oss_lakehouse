with source as (
    select * from {{ ref('raw_customers') }}
),

typed as (
    select
        customer_id,
        first_name,
        last_name,
        email,
        city,
        {{ safe_decimal('credit_score', 3, 0) }} as credit_score,
        {{ safe_timestamp('created_at') }} as created_at
    from source
)

select
    customer_id,
    first_name,
    last_name,
    {{ mask_pii('email') }} as email_masked,
    {{ hash_column('email') }} as email_hash,
    email as email_raw,
    city,
    credit_score,
    created_at,
    cast(created_at as date) as created_date_only,
    year(created_at) as created_year,
    month(created_at) as created_month,
    {{ age_years('created_at') }} as customer_age_years,
    case
        when credit_score >= 800 then 'Excellent'
        when credit_score >= 740 then 'Good'
        when credit_score >= 670 then 'Fair'
        when credit_score >= 580 then 'Poor'
        else 'Bad'
    end as credit_rating,
    case
        when {{ age_years('created_at') }} > 5 and credit_score >= 740 then 'Platinum'
        when {{ age_years('created_at') }} > 3 and credit_score >= 670 then 'Gold'
        when {{ age_years('created_at') }} > 1 then 'Silver'
        else 'Bronze'
    end as customer_tier
from typed
