with source as (
    select * from {{ ref('raw_loans') }}
),

typed as (
    select
        loan_id,
        customer_id,
        {{ safe_decimal('loan_amount', 15, 2) }} as loan_amount,
        {{ safe_decimal('interest_rate', 5, 2) }} as interest_rate,
        {{ safe_timestamp('start_date') }} as start_date
    from source
),

derived as (
    select
        *,
        -- 5-year term for demonstration
        start_date + interval 5 year as maturity_date,
        -- simplified PMT over 60 periods
        case
            when interest_rate > 0 then round(
                (loan_amount * (interest_rate / 100) * power(1 + interest_rate / 100, 60))
                / (power(1 + interest_rate / 100, 60) - 1),
                2
            )
            else round(loan_amount / 60, 2)
        end as estimated_monthly_payment
    from typed
)

select
    loan_id,
    customer_id,
    loan_amount,
    interest_rate,
    start_date,
    cast(start_date as date) as start_date_only,
    year(start_date) as start_year,
    month(start_date) as start_month,
    maturity_date,
    {{ date_diff('start_date', now_ts(), 'month') }} as loan_age_months,
    case
        when maturity_date < {{ now_ts() }} then 'Completed'
        when {{ date_diff('start_date', now_ts(), 'year') }} >= 4 then 'Near Maturity'
        when {{ date_diff('start_date', now_ts(), 'year') }} >= 3 then 'Mid-Term'
        when {{ date_diff('start_date', now_ts(), 'year') }} >= 1 then 'Active'
        else 'Recent'
    end as loan_status,
    estimated_monthly_payment,
    round(estimated_monthly_payment * 60 - loan_amount, 2) as total_interest_estimate,
    case
        when interest_rate >= 10 then 'High Interest'
        when interest_rate >= 7 then 'Medium Interest'
        else 'Low Interest'
    end as interest_category,
    loan_amount as loan_amount_display
from derived
