with source as (
    select
        l_orderkey,
        l_partkey,
        l_suppkey,
        l_linenumber,
        l_quantity,
        l_extendedprice,
        l_discount,
        l_tax,
        l_returnflag,
        l_linestatus,
        l_shipdate,
        l_commitdate,
        l_receiptdate,
        l_shipinstruct,
        l_shipmode,
        l_comment
    from {{ source('tpch', 'lineitem') }}
),

renamed as (
    select
        l_orderkey                                          as order_id,
        l_partkey                                           as part_id,
        l_suppkey                                           as supplier_id,
        l_linenumber                                        as line_number,
        l_quantity                                          as quantity,
        l_extendedprice                                     as gross_amount,
        l_discount                                          as discount_rate,
        l_tax                                               as tax_rate,
        round(l_extendedprice * (1 - l_discount), 2)       as net_amount,
        round(l_extendedprice * (1 - l_discount)
              * (1 + l_tax), 2)                             as net_amount_with_tax,
        l_returnflag                                        as return_flag,
        l_linestatus                                        as line_status,
        l_shipdate                                          as ship_date,
        l_commitdate                                        as commit_date,
        l_receiptdate                                       as receipt_date,
        datediff('day', l_shipdate, l_receiptdate)          as days_to_receive,
        datediff('day', l_commitdate, l_receiptdate)        as days_late,
        l_shipinstruct                                      as ship_instructions,
        l_shipmode                                          as ship_mode,
        l_comment                                           as line_comment
    from source
)

select * from renamed
