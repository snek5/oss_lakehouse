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
        loan_age_months
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
    case
        when l.interest_rate > 10 and c.credit_score < 670 then 'High Risk'
        when l.interest_rate > 7 and c.credit_score < 700 then 'Medium Risk'
        else 'Low Risk'
    end as risk_category,
    {{ percentile('l.interest_rate', 0.75) }} over () as interest_rate_75th_percentile,
    {{ percentile('l.loan_amount', 0.9) }} over () as loan_amount_90th_percentile,
    l.loan_amount / nullif(sum(l.loan_amount) over (), 0) * 100 as loan_percentage_of_portfolio,
    round(l.loan_amount * (l.interest_rate / 100), 2) as projected_annual_interest_income,
    {{ age_years('l.start_date') }} as loan_age_years,
    {{ date_diff(now_ts(), 'l.maturity_date', 'month') }} as months_to_maturity,
    case
        when l.maturity_date < {{ now_ts() }} then 'Matured'
        when {{ date_diff(now_ts(), 'l.maturity_date', 'month') }} <= 6 then 'Near Maturity'
        else 'Active'
    end as maturity_status,
    {{ generate_surrogate_key(['l.loan_id', 'l.start_date']) }} as loan_sk
from loans l
left join customers c on l.customer_id = c.customer_id
