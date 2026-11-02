with

base as (
    select * from {{ ref('base_wordpress__wp_post') }}
),

filtered as (
    select * from base
    where wp_post_type = 'course-bundle'
),

renamed as (
    select
        -- Keys
        wp_post_id as wp_course_bundle_id,
        -- Name, desc
        wp_post_title as wp_course_bundle_title,
        wp_post_excerpt as wp_course_bundle_summary,
        -- Attributes
        wp_post_status as wp_course_bundle_status_code,
        wp_post_slug as wp_course_bundle_slug,
        posted_at as published_at,
        modified_at as updated_at,
        -- Instructor
        author_wp_user_id as instructor_wp_user_id
    from filtered
),

decoded as (
    select
        *,
        case wp_course_bundle_status_code
            when 'publish' then 'Published'
            when 'draft' then 'Draft'
            when 'pending' then 'Pending Review'
            when 'private' then 'Private'
            when 'future' then 'Scheduled'
            else 'Unknown'
        end as wp_course_bundle_status
    from renamed
),

null_handled as (
    select
        -- Keys
        wp_course_bundle_id,
        -- Name, desc
        coalesce(nullif(trim(wp_course_bundle_title), ''), 'Unknown') as wp_course_bundle_title,
        coalesce(nullif(trim(wp_course_bundle_summary), ''), 'Unknown') as wp_course_bundle_summary,
        -- Attributes
        wp_course_bundle_status,
        coalesce(nullif(trim(wp_course_bundle_slug), ''), 'Unknown') as wp_course_bundle_slug,
        published_at,
        updated_at,
        -- Instructor
        coalesce(nullif(instructor_wp_user_id, 0), -1) as instructor_wp_user_id   -- WordPress writes 0 for no author
    from decoded
)

select * from null_handled
