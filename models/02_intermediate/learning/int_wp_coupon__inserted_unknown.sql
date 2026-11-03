with

coupon as (
    select * from {{ ref('stg_wordpress__wp_coupon') }}
),

unknown_coupon as (
    select
        -- Keys
        'UNKNOWN' as wp_coupon_code,
        -- Name, desc
        'Unknown' as wp_coupon_title,
        -- Attributes
        'Unknown' as wp_coupon_status,
        'Unknown' as wp_coupon_type,
        'Unknown' as wp_coupon_discount_type,
        null::numeric as wp_coupon_discount_value,
        'Unknown' as wp_coupon_applies_to,
        null::timestamp as starts_at,
        null::timestamp as expires_at
),

inserted_unknown as (
    select * from coupon
    union all
    select * from unknown_coupon
)

select * from inserted_unknown
