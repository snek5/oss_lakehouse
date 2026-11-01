with source as (
    select * from {{ ref('raw_branches') }}
)

select
    branch_id,
    branch_name,
    manager_name,
    nullif(city, '') as city,
    nullif(country, '') as country
from source
