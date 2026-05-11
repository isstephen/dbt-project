with source as (
    select * from {{ ref('raw_orders') }}
),

renamed as (
    select
        cast(order_id as varchar(64)) as order_id,
        cast(customer_id as varchar(64)) as customer_id,
        cast(order_total as numeric(18, 2)) as order_total,
        lower(cast(order_status as varchar(32))) as order_status,
        cast(created_at as timestamp) as created_at
    from source
)

select * from renamed
