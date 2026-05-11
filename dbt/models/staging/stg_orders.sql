with source as (
    select * from {{ source('raw', 'orders') }}
),

renamed as (
    select
        cast(order_id as varchar) as order_id,
        cast(customer_id as varchar) as customer_id,
        cast(order_total as numeric(18, 2)) as order_total,
        lower(cast(order_status as varchar)) as order_status,
        cast(created_at as timestamp) as created_at
    from source
)

select * from renamed
