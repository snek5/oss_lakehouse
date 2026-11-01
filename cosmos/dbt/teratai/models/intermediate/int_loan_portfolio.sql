{{
    config(
        materialized='view',
        tags=['intermediate', 'loan_portfolio']
    )
}}

with loans as (
    select 
        loan_id,
        customer_id,
        loan_amount,
        interest_rate,
        start_date,
        maturity_date,
        loan_status,
        estimated_monthly_payment,
        total_interest_estimate,
        interest_category,
        loan_age_months,
        start_year,
        start_month
    from {{ ref('stg_loans') }}
),

customers as (
    select 
        customer_id,
        first_name,
        last_name,
        credit_score,
        credit_rating,
        customer_tier
    from {{ ref('stg_customers') }}
),

-- Use macro for risk scoring
loan_risk as (
    select
        loan_id,
        customer_id,
        -- Risk score based on multiple factors using macro calculations
        case 
            when interest_rate > 10 and credit_score < 670 then 'High Risk'
            when interest_rate > 7 and credit_score < 700 then 'Medium Risk'
            else 'Low Risk'
        end as risk_category,
        -- Use macro for percentile
        {{ percentile('interest_rate', 0.75) }} over () as interest_rate_75th_percentile,
        {{ percentile('loan_amount', 0.9) }} over () as loan_amount_90th_percentile
    from loans
)

select
    l.loan_id,
    l.customer_id,
    c.first_name || ' ' || c.last_name as customer_name,
    c.credit_score,
    c.credit_rating,
    c.customer_tier,
    l.loan_amount,
    l.interest_rate,
    l.start_date,
    l.maturity_date,
    l.loan_status,
    l.estimated_monthly_payment,
    l.total_interest_estimate,
    l.interest_category,
    l.loan_age_months,
    -- Risk assessment
    lr.risk_category,
    lr.interest_rate_75th_percentile,
    lr.loan_amount_90th_percentile,
    -- Portfolio metrics using macros
    {{ safe_decimal('l.loan_amount', 15, 2) }} / nullif(
        sum(l.loan_amount) over (),
        0
    ) * 100 as loan_percentage_of_portfolio,
    -- Interest income projection (annual)
    round(l.loan_amount * (l.interest_rate / 100), 2) as projected_annual_interest_income,
    -- Use macro for age calculation
    {{ age_years('l.start_date') }} as loan_age_years,
    -- Remaining term in months
    timestampdiff(MONTH, current_timestamp(), l.maturity_date) as months_to_maturity,
    -- Maturity status
    case 
        when l.maturity_date < current_timestamp() then 'Matured'
        when timestampdiff(MONTH, current_timestamp(), l.maturity_date) <= 6 then 'Near Maturity'
        else 'Active'
    end as maturity_status,
    -- Generate surrogate key using macro
    {{ generate_surrogate_key(['l.loan_id', 'l.start_date']) }} as loan_sk
from loans l
left join customers c on l.customer_id = c.customer_id
left join loan_risk lr on l.loan_id = lr.loan_id