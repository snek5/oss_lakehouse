with loans as (
    select * from {{ ref('int_loan_portfolio') }}
),

portfolio_metrics as (
    select
        loan_status,
        risk_category,
        interest_category,
        maturity_status,
        count(loan_id) as loan_count,
        sum(loan_amount) as total_loan_value,
        avg(interest_rate) as avg_interest_rate,
        {{ percentile('interest_rate', 0.5) }} as median_interest_rate,
        {{ percentile('loan_amount', 0.9) }} as p90_loan_amount,
        sum(projected_annual_interest_income) as total_annual_interest_income,
        avg(credit_score) as avg_borrower_credit_score,
        sum(case
            when risk_category = 'High Risk' then loan_amount * 1.5
            when risk_category = 'Medium Risk' then loan_amount * 1.0
            else loan_amount * 0.5
        end) as risk_weighted_assets
    from loans
    group by 1, 2, 3, 4
),

-- share of the whole book held by each risk category
concentration_metrics as (
    select
        risk_category,
        round(sum(total_loan_value) / nullif(sum(sum(total_loan_value)) over (), 0) * 100, 2)
            as portfolio_concentration_percentage
    from portfolio_metrics
    where risk_category is not null
    group by 1
)

select
    pm.loan_status,
    pm.risk_category,
    pm.interest_category,
    pm.maturity_status,
    pm.loan_count,
    pm.total_loan_value,
    pm.avg_interest_rate,
    pm.median_interest_rate,
    pm.p90_loan_amount,
    pm.total_annual_interest_income,
    pm.avg_borrower_credit_score,
    pm.risk_weighted_assets,
    cm.portfolio_concentration_percentage,
    case
        when pm.risk_category = 'High Risk' and pm.total_loan_value > 1000000 then 'Critical Exposure'
        when pm.risk_category = 'High Risk' then 'High Exposure'
        when pm.risk_category = 'Medium Risk' and pm.total_loan_value > 2000000 then 'Moderate Exposure'
        else 'Healthy Portfolio'
    end as portfolio_health_status,
    round(pm.total_annual_interest_income / nullif(pm.total_loan_value, 0) * 100, 2) as yield_on_portfolio,
    -- crude default-risk proxy from the 300-850 credit score scale (0 = safest, 1 = riskiest)
    round((850 - pm.avg_borrower_credit_score) / 550, 2) as estimated_default_risk,
    current_timestamp as analysis_timestamp
from portfolio_metrics pm
left join concentration_metrics cm on pm.risk_category = cm.risk_category
