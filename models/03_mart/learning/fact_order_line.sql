-- A table, not incremental: Tutor does not bump wp_tutor_orders.updated_at_gmt on
-- every change (ingestion/wordpress/.dlt/config.toml), so there is no reliable cursor.

with

order_line as (
    select * from {{ ref('int_wp_order_line__joined_to_header') }}
),

final as (
    select
        -- Keys
        wp_order_line_no,    -- primary key, degenerate dimension, line-level
        wp_order_no,         -- degenerate dimension, header-level
        -- Foreign keys
        ordered_by_wp_user_id,
        wp_course_id,
        wp_coupon_code,
        -- Attributes
        payment_transaction_no,
        wp_order_type,
        wp_order_status,
        payment_status,
        payment_method,
        -- Foreign keys
        {{ dbt_utils.generate_surrogate_key(['ordered_by_wp_user_id']) }} as ordered_by_wp_user_key,
        {{ dbt_utils.generate_surrogate_key(['wp_course_id']) }} as wp_course_key,
        -- Dates
        ordered_at,
        updated_at,
        -- Measures
        regular_unit_price,
        sale_unit_price,
        discounted_unit_price,
        gross_amt,
        discount_amt,
        net_amt
    from order_line
)

select * from final
