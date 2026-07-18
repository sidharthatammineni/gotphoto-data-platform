{% snapshot orders_snapshot %}

{{
    config(
        target_schema = 'snapshots',
        unique_key    = 'order_id',
        strategy      = 'check',
        check_cols    = ['order_status', 'order_total_price'],
    )
}}

select
    order_id,
    customer_id,
    order_status,
    order_total_price,
    order_date,
    order_priority
from {{ ref('stg_tpch__orders') }}

{% endsnapshot %}
