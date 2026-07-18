{{
  config(
    materialized = 'table',
    description  = 'Customer-level analytical table. Grain: one row per customer. Intended for customer segmentation, lifetime value analysis, and churn identification.'
  )
}}

with customer_orders as (
    select
        customer_id,
        count(*)                            as total_orders,
        sum(order_total_price)              as lifetime_revenue,
        avg(order_total_price)              as avg_order_value,
        min(order_date)                     as first_order_date,
        max(order_date)                     as last_order_date,
        datediff('day',
            min(order_date),
            max(order_date))                as customer_tenure_days,
        sum(line_item_count)                as total_line_items,
        sum(returned_line_count)            as total_returned_lines,
        sum(late_delivery_count)            as total_late_deliveries,
        avg(return_rate)                    as avg_return_rate,
        avg(days_to_first_shipment)         as avg_days_to_shipment,
        count(case when order_status = 'O' then 1 end) as open_orders,
        count(case when order_status = 'F' then 1 end) as fulfilled_orders
    from {{ ref('int_orders__enriched') }}
    group by 1
)

select
    c.customer_id,
    c.customer_name,
    c.market_segment,
    c.nation_name,
    c.region_name,
    c.customer_account_balance,

    co.total_orders,
    co.lifetime_revenue,
    co.avg_order_value,
    co.first_order_date,
    co.last_order_date,
    co.customer_tenure_days,
    co.total_line_items,
    co.total_returned_lines,
    co.total_late_deliveries,
    round(co.avg_return_rate, 4)            as avg_return_rate,
    round(co.avg_days_to_shipment, 1)       as avg_days_to_shipment,
    co.open_orders,
    co.fulfilled_orders,

    case
        when co.lifetime_revenue >= 1000000 then 'Platinum'
        when co.lifetime_revenue >= 500000  then 'Gold'
        when co.lifetime_revenue >= 100000  then 'Silver'
        else 'Bronze'
    end as customer_tier

from {{ ref('int_orders__enriched') }} c
inner join customer_orders co on c.customer_id = co.customer_id
qualify row_number() over (partition by c.customer_id order by c.order_date desc) = 1
