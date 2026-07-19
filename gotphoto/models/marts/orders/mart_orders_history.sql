{{
  config(
    materialized = 'view',
    description  = 'Historical order records with SCD Type 2 tracking. Grain: one row per order version. Use is_current = true to get the latest version of each order.'
  )
}}

select
    order_id,
    customer_id,
    order_status,
    order_total_price,
    order_date,
    order_priority,
    dbt_valid_from,
    dbt_valid_to,
    case when dbt_valid_to is null then true else false end as is_current
from {{ ref('orders_snapshot') }}
