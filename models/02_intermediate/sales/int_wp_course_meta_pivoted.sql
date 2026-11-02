with

course as (
    select wp_course_id from {{ ref('stg_wordpress__wp_course') }}
),

post_meta as (
    select * from {{ ref('stg_wordpress__wp_post_meta') }}
),

pivoted as (
    select
        -- Keys
        course.wp_course_id,
        -- Attributes
        max(post_meta.meta_value) filter (where post_meta.meta_key = '_tutor_course_price_type') as wp_course_price_type_code,
        max(post_meta.meta_value) filter (where post_meta.meta_key = '_tutor_course_level') as wp_course_level_code,
        max(post_meta.meta_value) filter (where post_meta.meta_key = '_tutor_is_public_course') as wp_course_public_code,
        max(post_meta.meta_value) filter (where post_meta.meta_key = 'tutor_course_price') as regular_unit_price,
        max(post_meta.meta_value) filter (where post_meta.meta_key = 'tutor_course_sale_price') as sale_unit_price
    from course
    left join post_meta on course.wp_course_id = post_meta.wp_post_id
    group by course.wp_course_id
),

casted as (
    select
        -- Keys
        wp_course_id,
        -- Attributes
        wp_course_price_type_code,
        wp_course_level_code,
        wp_course_public_code,
        cast(nullif(trim(regular_unit_price), '') as numeric) as regular_unit_price,
        cast(nullif(nullif(trim(sale_unit_price), ''), '0') as numeric) as sale_unit_price   -- Tutor writes 0 when not on sale
    from pivoted
),

decoded as (
    select
        *,
        case wp_course_price_type_code
            when 'paid' then 'Paid'
            when 'free' then 'Free'
            else 'Unknown'
        end as wp_course_price_type,
        case wp_course_level_code
            when 'all_levels' then 'All Levels'
            when 'beginner' then 'Beginner'
            when 'intermediate' then 'Intermediate'
            when 'expert' then 'Expert'
            else 'Unknown'                          -- bundles have no level
        end as wp_course_level,
        case wp_course_public_code
            when 'yes' then 'Public'
            when 'no' then 'Not Public'
            else 'Unknown'
        end as wp_course_public_indicator
    from casted
),

final as (
    select
        -- Keys
        wp_course_id,
        -- Attributes
        wp_course_price_type,
        wp_course_level,
        wp_course_public_indicator,
        regular_unit_price,
        sale_unit_price
    from decoded
)

select * from final
