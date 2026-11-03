with

order_line as (
    select * from {{ ref('stg_wordpress__wp_order_line') }}
),

order_header as (
    select * from {{ ref('stg_wordpress__wp_order') }}
),

joined_to_header as (
    select
        -- Keys
        order_line.wp_order_no,
        order_line.wp_order_line_no,
        -- Foreign keys
        order_header.ordered_by_wp_user_id,
        order_line.wp_course_id,
        order_line.wp_coupon_code,
        -- Attributes
        order_header.payment_transaction_no,
        order_header.wp_order_type,
        order_header.wp_order_status,
        order_header.payment_status,
        order_header.payment_method,
        -- Dates
        order_header.ordered_at,
        order_header.updated_at,
        -- Measures
        order_line.regular_unit_price,
        order_line.sale_unit_price,
        order_line.discounted_unit_price,
        order_line.gross_amt,
        order_line.discount_amt,
        order_line.net_amt
    from order_line
    inner join order_header on order_line.wp_order_no = order_header.wp_order_no
)

select * from joined_to_header
