with source as (
    select * from {{ source('raw', 'customers') }}
),

renamed as (
    select
        customer_id,
        first_name,
        last_name,
        {{ mask_pii('email') }} as email_masked,  -- Mask PII
        {{ hash_column('email') }} as email_hash,  -- Hash for joining
        email as email_raw,  -- Keep raw for reference
        city,
        {{ safe_decimal('credit_score', 3, 0) }} as credit_score,
        {{ safe_timestamp('created_at') }} as created_at,
        date({{ safe_timestamp('created_at') }}) as created_date_only,
        year({{ safe_timestamp('created_at') }}) as created_year,
        month({{ safe_timestamp('created_at') }}) as created_month,
        {{ age_years('created_at') }} as customer_age_years,
        case 
            when {{ safe_decimal('credit_score', 3, 0) }} >= 800 then 'Excellent'
            when {{ safe_decimal('credit_score', 3, 0) }} >= 740 then 'Good'
            when {{ safe_decimal('credit_score', 3, 0) }} >= 670 then 'Fair'
            when {{ safe_decimal('credit_score', 3, 0) }} >= 580 then 'Poor'
            else 'Bad'
        end as credit_rating,
        -- Customer tier based on age and credit
        case 
            when {{ age_years('created_at') }} > 5 and {{ safe_decimal('credit_score', 3, 0) }} >= 740 then 'Platinum'
            when {{ age_years('created_at') }} > 3 and {{ safe_decimal('credit_score', 3, 0) }} >= 670 then 'Gold'
            when {{ age_years('created_at') }} > 1 then 'Silver'
            else 'Bronze'
        end as customer_tier
    from source
)

select * from renamed