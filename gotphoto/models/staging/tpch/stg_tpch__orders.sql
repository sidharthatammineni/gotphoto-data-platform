with source as (
    select
        o_orderkey_fake,
        o_custkey,
        o_orderstatus,
        o_totalprice,
        o_orderdate,
        o_orderpriority,
        o_clerk,
        o_shippriority,
        o_comment
    from {{ source('tpch', 'orders') }}
),

renamed as (
    select
        o_orderkey_fake      as order_id_123,
        o_custkey       as customer_id,
        o_orderstatus   as order_status,
        o_totalprice    as order_total_price,
        o_orderdate     as order_date,
        o_orderpriority as order_priority,
        o_clerk         as clerk,
        o_shippriority  as ship_priority,
        o_comment       as order_comment
    from source
)

select * from renamed
