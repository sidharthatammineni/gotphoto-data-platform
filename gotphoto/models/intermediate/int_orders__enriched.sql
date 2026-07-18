with orders as (
    select * from {{ ref('stg_tpch__orders') }}
),

customers as (
    select * from {{ ref('stg_tpch__customers') }}
),

nations as (
    select * from {{ ref('stg_tpch__nations') }}
),

regions as (
    select * from {{ ref('stg_tpch__regions') }}
),

lineitems_agg as (
    select
        order_id,
        count(*)                        as line_item_count,
        sum(gross_amount)               as total_gross_amount,
        sum(net_amount)                 as total_net_amount,
        sum(net_amount_with_tax)        as total_net_amount_with_tax,
        min(ship_date)                  as first_ship_date,
        max(ship_date)                  as last_ship_date,
        sum(case when return_flag = 'R' then 1 else 0 end) as returned_line_count,
        sum(case when days_late > 0 then 1 else 0 end)     as late_delivery_count
    from {{ ref('stg_tpch__lineitems') }}
    group by 1
)

select
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_date,
    o.order_priority,
    o.order_total_price,

    c.customer_name,
    c.market_segment,
    c.account_balance as customer_account_balance,

    n.nation_name,
    r.region_name,

    li.line_item_count,
    li.total_gross_amount,
    li.total_net_amount,
    li.total_net_amount_with_tax,
    li.first_ship_date,
    li.last_ship_date,
    li.returned_line_count,
    li.late_delivery_count,

    datediff('day', o.order_date, li.first_ship_date) as days_to_first_shipment,
    round({{ safe_divide('li.returned_line_count', 'li.line_item_count') }}, 4) as return_rate

from orders o
left join customers c on o.customer_id = c.customer_id
left join nations n on c.nation_id = n.nation_id
left join regions r on n.region_id = r.region_id
left join lineitems_agg li on o.order_id = li.order_id
