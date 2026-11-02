with

course as (
    select * from {{ ref('stg_wordpress__wp_course') }}
),

course_meta as (
    select * from {{ ref('int_wp_course__meta_pivoted') }}
),

joined_to_meta as (
    select
        -- Keys
        course.wp_course_id,
        -- Name, desc
        course.wp_course_title,
        course.wp_course_summary,
        -- Attributes
        course.wp_course_type,
        course.wp_course_status,
        course.wp_course_slug,
        coalesce(course_meta.wp_course_price_type, 'Unknown') as wp_course_price_type,
        coalesce(course_meta.wp_course_level, 'Unknown') as wp_course_level,
        coalesce(course_meta.wp_course_public_indicator, 'Unknown') as wp_course_public_indicator,
        course_meta.regular_unit_price,
        course_meta.sale_unit_price,
        course.published_at,
        course.updated_at,
        -- Instructor
        course.instructor_wp_user_id
    from course
    left join course_meta on course.wp_course_id = course_meta.wp_course_id
),

unknown_course as (
    select
        -- Keys
        -1 as wp_course_id,
        -- Name, desc
        'Unknown' as wp_course_title,
        'Unknown' as wp_course_summary,
        -- Attributes
        'Unknown' as wp_course_type,
        'Unknown' as wp_course_status,
        'Unknown' as wp_course_slug,
        'Unknown' as wp_course_price_type,
        'Unknown' as wp_course_level,
        'Unknown' as wp_course_public_indicator,
        null::numeric as regular_unit_price,
        null::numeric as sale_unit_price,
        null::timestamp as published_at,
        null::timestamp as updated_at,
        -- Instructor
        -1 as instructor_wp_user_id
),

inserted_unknown as (
    select * from joined_to_meta
    union all
    select * from unknown_course
)

select * from inserted_unknown
