select
    cast(created_at as date) as order_date,
    count(*) as order_count,
    sum(order_total) as gross_revenue,
    sum(case when order_status = 'refunded' then order_total else 0 end) as refunded_revenue
from {{ ref('stg_orders') }}
group by 1
