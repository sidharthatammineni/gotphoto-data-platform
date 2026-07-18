{{
  config(
    materialized = 'table',
    description  = 'Order-level analytical table. Grain: one row per order. Intended for dashboards and analysts tracking order volume, revenue, and fulfillment performance.'
  )
}}

select
    order_id,
    customer_id,
    customer_name,
    market_segment,
    nation_name,
    region_name,
    order_date,
    date_trunc('month', order_date)     as order_month,
    date_trunc('quarter', order_date)   as order_quarter,
    year(order_date)                    as order_year,
    order_status,
    order_priority,
    order_total_price,
    total_gross_amount,
    total_net_amount,
    total_net_amount_with_tax,
    line_item_count,
    returned_line_count,
    late_delivery_count,
    return_rate,
    days_to_first_shipment,
    first_ship_date,
    last_ship_date,
    customer_account_balance
from {{ ref('int_orders__enriched') }}
