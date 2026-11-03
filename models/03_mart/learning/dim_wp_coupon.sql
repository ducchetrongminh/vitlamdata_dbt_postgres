with

coupon as (
    select * from {{ ref('int_wp_coupon__inserted_unknown') }}
),

final as (
    select
        -- Keys
        {{ dbt_utils.generate_surrogate_key(['wp_coupon_id']) }} as wp_coupon_key,
        wp_coupon_id,
        -- Name, desc
        wp_coupon_title,
        -- Attributes
        wp_coupon_status,
        wp_coupon_type,
        wp_coupon_discount_type,
        wp_coupon_discount_value,
        wp_coupon_applies_to,
        starts_at,
        expires_at
    from coupon
)

select * from final
