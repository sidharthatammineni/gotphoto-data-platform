{{
  config(
    materialized = 'table',
    description  = 'Monthly revenue summary. Grain: one row per month + market segment + region. Intended for finance reporting, trend analysis, and executive dashboards.'
  )
}}

select
    date_trunc('month', order_date)         as order_month,
    year(order_date)                        as order_year,
    market_segment,
    region_name,
    nation_name,

    count(distinct order_id)                as order_count,
    count(distinct customer_id)             as active_customers,
    sum(order_total_price)                  as gross_revenue,
    sum(total_net_amount)                   as net_revenue,
    sum(total_net_amount_with_tax)          as net_revenue_with_tax,
    avg(order_total_price)                  as avg_order_value,
    sum(line_item_count)                    as total_line_items,
    sum(returned_line_count)                as total_returns,
    round({{ safe_divide('sum(returned_line_count)', 'sum(line_item_count)') }}, 4) as overall_return_rate,
    sum(late_delivery_count)                as total_late_deliveries,
    round({{ safe_divide('sum(late_delivery_count)', 'sum(line_item_count)') }}, 4) as late_delivery_rate

from {{ ref('int_orders__enriched') }}
group by 1, 2, 3, 4, 5
