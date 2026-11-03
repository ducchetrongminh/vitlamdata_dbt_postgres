with

source as (
    select * from {{ source('wordpress', 'wp_tutor_coupons') }}
),

filtered as (
    select * from source
    where coupon_status <> 'trash'
),

renamed as (
    select
        -- Keys
        id as wp_coupon_id,
        coupon_code as wp_coupon_code,     -- secret while the coupon is usable; never past intermediate
        -- Name, desc
        coupon_title as wp_coupon_title,
        -- Attributes
        coupon_status as wp_coupon_status_code,
        coupon_type as wp_coupon_type_code,
        discount_type as wp_coupon_discount_type_code,
        discount_amount as wp_coupon_discount_value,
        applies_to as wp_coupon_applies_to_code,
        start_date_gmt as starts_at_utc,
        expire_date_gmt as expires_at_utc
    from filtered
),

casted as (
    select
        -- Keys
        cast(wp_coupon_id as bigint) as wp_coupon_id,
        cast(wp_coupon_code as text) as wp_coupon_code,
        -- Name, desc
        cast(wp_coupon_title as text) as wp_coupon_title,
        -- Attributes
        cast(wp_coupon_status_code as text) as wp_coupon_status_code,
        cast(wp_coupon_type_code as text) as wp_coupon_type_code,
        cast(wp_coupon_discount_type_code as text) as wp_coupon_discount_type_code,
        cast(wp_coupon_discount_value as numeric) as wp_coupon_discount_value,
        cast(wp_coupon_applies_to_code as text) as wp_coupon_applies_to_code,
        cast(starts_at_utc as timestamp) at time zone 'UTC' at time zone 'Asia/Ho_Chi_Minh' as starts_at,
        cast(expires_at_utc as timestamp) at time zone 'UTC' at time zone 'Asia/Ho_Chi_Minh' as expires_at
    from renamed
),

decoded as (
    select
        *,
        case wp_coupon_status_code
            when 'active' then 'Active'
            when 'inactive' then 'Inactive'
            else 'Unknown'
        end as wp_coupon_status,
        case wp_coupon_type_code
            when 'code' then 'Code'
            when 'automatic' then 'Automatic'
            else 'Unknown'
        end as wp_coupon_type,
        case wp_coupon_discount_type_code
            when 'flat' then 'Flat'
            when 'percentage' then 'Percentage'
            else 'Unknown'
        end as wp_coupon_discount_type,
        case wp_coupon_applies_to_code
            when 'all_courses_and_bundles' then 'All Courses and Bundles'
            when 'all_courses' then 'All Courses'
            when 'all_bundles' then 'All Bundles'
            when 'specific_courses' then 'Specific Courses'
            when 'specific_bundles' then 'Specific Bundles'
            when 'specific_category' then 'Specific Category'
            else 'Unknown'
        end as wp_coupon_applies_to
    from casted
),

null_handled as (
    select
        -- Keys
        wp_coupon_id,
        wp_coupon_code,
        -- Name, desc
        coalesce(nullif(trim(wp_coupon_title), ''), 'Unknown') as wp_coupon_title,
        -- Attributes
        wp_coupon_status,
        wp_coupon_type,
        wp_coupon_discount_type,
        wp_coupon_discount_value,
        wp_coupon_applies_to,
        starts_at,
        expires_at
    from decoded
)

select * from null_handled
