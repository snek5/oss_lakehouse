with source as (
    select * from {{ source('raw', 'loans') }}
),

renamed as (
    select
        loan_id,
        customer_id,
        {{ safe_decimal('loan_amount', 15, 2) }} as loan_amount,
        {{ safe_decimal('interest_rate', 5, 2) }} as interest_rate,
        {{ safe_timestamp('start_date') }} as start_date,
        date({{ safe_timestamp('start_date') }}) as start_date_only,
        year({{ safe_timestamp('start_date') }}) as start_year,
        month({{ safe_timestamp('start_date') }}) as start_month,
        -- Loan maturity (assuming 5-year term for demonstration)
        date_add('year', 5, {{ safe_timestamp('start_date') }}) as maturity_date,
        -- Loan age in months
        timestampdiff(MONTH, {{ safe_timestamp('start_date') }}, current_timestamp()) as loan_age_months,
        -- Loan status
        case 
            when date_add('year', 5, {{ safe_timestamp('start_date') }}) < current_timestamp() then 'Completed'
            when timestampdiff(YEAR, {{ safe_timestamp('start_date') }}, current_timestamp()) >= 4 then 'Near Maturity'
            when timestampdiff(YEAR, {{ safe_timestamp('start_date') }}, current_timestamp()) >= 3 then 'Mid-Term'
            when timestampdiff(YEAR, {{ safe_timestamp('start_date') }}, current_timestamp()) >= 1 then 'Active'
            else 'Recent'
        end as loan_status,
        -- Calculate monthly payment using PMT formula (simplified)
        case 
            when {{ safe_decimal('interest_rate', 5, 2) }} > 0 then
                round(
                    ({{ safe_decimal('loan_amount', 15, 2) }} * ({{ safe_decimal('interest_rate', 5, 2) }} / 100) * 
                    power(1 + ({{ safe_decimal('interest_rate', 5, 2) }} / 100), 60)) /
                    (power(1 + ({{ safe_decimal('interest_rate', 5, 2) }} / 100), 60) - 1),
                    2
                )
            else {{ safe_decimal('loan_amount', 15, 2) }} / 60
        end as estimated_monthly_payment,
        -- Total interest estimate
        round(
            ({{ safe_decimal('estimated_monthly_payment') }} * 60) - {{ safe_decimal('loan_amount', 15, 2) }},
            2
        ) as total_interest_estimate,
        -- Interest rate category
        case 
            when {{ safe_decimal('interest_rate', 5, 2) }} >= 10 then 'High Interest'
            when {{ safe_decimal('interest_rate', 5, 2) }} >= 7 then 'Medium Interest'
            else 'Low Interest'
        end as interest_category,
        -- Loan-to-income proxy (using simplified logic)
        {{ safe_decimal('loan_amount', 15, 2) }} as loan_amount_display
    from source
)

select * from renamed