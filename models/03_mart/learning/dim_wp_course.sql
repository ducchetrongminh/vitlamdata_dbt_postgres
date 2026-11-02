with

course as (
    select * from {{ ref('int_wp_course__joined_to_meta') }}
),

final as (
    select
        -- Keys
        {{ dbt_utils.generate_surrogate_key(['wp_course_id']) }} as wp_course_key,
        wp_course_id,
        -- Name, desc
        wp_course_title,
        wp_course_summary,
        -- Attributes
        wp_course_type,
        wp_course_status,
        wp_course_slug,
        wp_course_price_type,
        wp_course_level,
        wp_course_public_indicator,
        regular_unit_price,
        sale_unit_price,
        published_at,
        updated_at,
        -- Instructor
        {{ dbt_utils.generate_surrogate_key(['instructor_wp_user_id']) }} as wp_instructor_key,
        instructor_wp_user_id as wp_instructor_id
    from course
)

select * from final
