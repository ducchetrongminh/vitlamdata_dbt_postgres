with

source as (
    select * from {{ source('wordpress', 'wp_tutor_order_items') }}
),

renamed as (
    select
        -- Keys
        id as wp_order_line_id,
        -- Foreign keys
        order_id as wp_order_id,
        item_id as wp_course_id,
        coupon_code as wp_coupon_code,
        -- Measures
        regular_price as regular_unit_price,
        sale_price as sale_unit_price,
        discount_price as discounted_unit_price
    from source
),

casted as (
    select
        -- Keys
        cast(wp_order_line_id as bigint) as wp_order_line_id,
        -- Foreign keys
        cast(wp_order_id as bigint) as wp_order_id,
        cast(wp_course_id as bigint) as wp_course_id,
        cast(wp_coupon_code as text) as wp_coupon_code,
        -- Measures
        cast(regular_unit_price as numeric) as regular_unit_price,
        cast(nullif(trim(sale_unit_price), '') as numeric) as sale_unit_price,               -- stored as text
        cast(nullif(trim(discounted_unit_price), '') as numeric) as discounted_unit_price    -- stored as text
    from renamed
),

null_handled as (
    select
        -- Keys
        wp_order_line_id,
        -- Foreign keys
        coalesce(nullif(wp_order_id, 0), -1) as wp_order_id,
        coalesce(nullif(wp_course_id, 0), -1) as wp_course_id,
        coalesce(nullif(trim(wp_coupon_code), ''), 'UNKNOWN') as wp_coupon_code,
        -- Measures
        regular_unit_price,
        sale_unit_price,
        discounted_unit_price
    from casted
)

select * from null_handled
