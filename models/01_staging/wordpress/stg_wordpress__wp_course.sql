with

base as (
    select * from {{ ref('base_wordpress__wp_post') }}
),

filtered as (
    select * from base
    where wp_post_type = 'courses'
),

renamed as (
    select
        wp_post_id as wp_course_id,
        author_wp_user_id as instructor_wp_user_id,
        wp_post_status as wp_course_status_code,
        wp_post_title as wp_course_title,
        wp_post_excerpt as wp_course_summary,
        wp_post_slug as wp_course_slug,
        posted_at as published_at,
        modified_at as updated_at
    from filtered
),

decoded as (
    select
        wp_course_id,
        instructor_wp_user_id,
        case wp_course_status_code
            when 'publish' then 'Published'
            when 'draft' then 'Draft'
            when 'pending' then 'Pending Review'
            when 'private' then 'Private'
            when 'future' then 'Scheduled'
            else 'Unknown'
        end as wp_course_status,
        wp_course_title,
        wp_course_summary,
        wp_course_slug,
        published_at,
        updated_at
    from renamed
),

null_handled as (
    select
        wp_course_id,
        coalesce(nullif(instructor_wp_user_id, 0), -1) as instructor_wp_user_id,   -- WordPress writes 0 for no author
        wp_course_status,
        coalesce(nullif(trim(wp_course_title), ''), 'Unknown') as wp_course_title,
        coalesce(nullif(trim(wp_course_summary), ''), 'Unknown') as wp_course_summary,
        coalesce(nullif(trim(wp_course_slug), ''), 'Unknown') as wp_course_slug,
        published_at,
        updated_at
    from decoded
)

select * from null_handled
