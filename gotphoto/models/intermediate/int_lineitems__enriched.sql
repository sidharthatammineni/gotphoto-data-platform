with lineitems as (
    select * from {{ ref('stg_tpch__lineitems') }}
),

parts as (
    select * from {{ ref('stg_tpch__parts') }}
),

suppliers as (
    select * from {{ ref('stg_tpch__suppliers') }}
),

nations as (
    select * from {{ ref('stg_tpch__nations') }}
),

regions as (
    select * from {{ ref('stg_tpch__regions') }}
)

select
    li.order_id,
    li.line_number,
    li.part_id,
    li.supplier_id,
    li.quantity,
    li.gross_amount,
    li.discount_rate,
    li.tax_rate,
    li.net_amount,
    li.net_amount_with_tax,
    li.return_flag,
    li.line_status,
    li.ship_date,
    li.commit_date,
    li.receipt_date,
    li.days_to_receive,
    li.days_late,
    li.ship_mode,

    p.part_name,
    p.brand,
    p.part_type,
    p.retail_price,
    round({{ safe_divide('li.gross_amount', 'li.quantity') }}, 2)                          as actual_unit_price,
    round(p.retail_price - {{ safe_divide('li.gross_amount', 'li.quantity') }}, 2)        as discount_vs_retail,

    s.supplier_name,
    n.nation_name   as supplier_nation,
    r.region_name   as supplier_region

from lineitems li
left join parts p       on li.part_id = p.part_id
left join suppliers s   on li.supplier_id = s.supplier_id
left join nations n     on s.nation_id = n.nation_id
left join regions r     on n.region_id = r.region_id
