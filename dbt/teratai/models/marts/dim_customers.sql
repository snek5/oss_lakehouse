with customer_360 as (
    select * from {{ ref('int_customer_360') }}
),

customer_segments as (
    select
        customer_id,
        case
            when wealth_quintile = 5 then 'Top 20%'
            when wealth_quintile = 4 then 'Upper Middle 20%'
            when wealth_quintile = 3 then 'Middle 20%'
            when wealth_quintile = 2 then 'Lower Middle 20%'
            else 'Bottom 20%'
        end as wealth_segment,
        case
            when total_balance_usd > 100000 and credit_rating in ('Excellent', 'Good') then 'Premium'
            when total_balance_usd > 50000 and credit_rating in ('Excellent', 'Good') then 'High Value'
            when total_balance_usd > 20000 and total_accounts > 1 then 'Standard'
            else 'Basic'
        end as customer_segment,
        case
            when credit_rating = 'Excellent' and customer_age_years < 3 then 'High Growth'
            when credit_rating = 'Good' and total_loans = 0 then 'Upsell Opportunity'
            when credit_rating in ('Fair', 'Poor') and total_loans > 0 then 'Risk'
            else 'Stable'
        end as growth_potential
    from customer_360
)

select
    c360.customer_sk,
    c360.customer_id,
    c360.customer_business_key,
    c360.first_name,
    c360.last_name,
    c360.email_masked,
    c360.customer_city,
    c360.credit_score,
    c360.credit_rating,
    c360.customer_tier,
    c360.customer_age_years,
    c360.created_at,
    c360.total_accounts,
    c360.total_balance_usd,
    c360.avg_account_balance,
    c360.account_types,
    c360.total_loans,
    c360.total_loan_amount,
    c360.avg_interest_rate,
    c360.total_cards,
    c360.credit_cards,
    c360.debit_cards,
    c360.expired_cards,
    c360.cards_expiring_soon,
    c360.net_worth,
    c360.debt_to_asset_ratio,
    c360.financial_health_status,
    cs.wealth_segment,
    cs.customer_segment,
    cs.growth_potential,
    {{ hash_column('c360.customer_id') }} as customer_id_hash,
    current_timestamp as dbt_updated_at,
    '{{ invocation_id }}' as dbt_invocation_id
from customer_360 c360
left join customer_segments cs on c360.customer_id = cs.customer_id
