with source as (
    select
        p_partkey,
        p_name,
        p_mfgr,
        p_brand,
        p_type,
        p_size,
        p_container,
        p_retailprice,
        p_comment
    from {{ source('tpch', 'part') }}
),

renamed as (
    select
        p_partkey       as part_id,
        p_name          as part_name,
        p_mfgr          as manufacturer,
        p_brand         as brand,
        p_type          as part_type,
        p_size          as part_size,
        p_container     as container_type,
        p_retailprice   as retail_price,
        p_comment       as part_comment
    from source
)

select * from renamed
