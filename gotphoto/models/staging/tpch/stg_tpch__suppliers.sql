with source as (
    select
        s_suppkey,
        s_name,
        s_address,
        s_nationkey,
        s_phone,
        s_acctbal,
        s_comment
    from {{ source('tpch', 'supplier') }}
),

renamed as (
    select
        s_suppkey       as supplier_id,
        s_name          as supplier_name,
        s_address       as supplier_address,
        s_nationkey     as nation_id,
        s_phone         as phone,
        s_acctbal       as account_balance,
        s_comment       as supplier_comment
    from source
)

select * from renamed
