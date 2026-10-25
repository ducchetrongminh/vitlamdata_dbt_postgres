with

base as (
    select * from {{ ref('base_wordpress__post') }}
),

filtered as (
    select * from base
    where post_type = 'courses'
),

renamed as (
    select
        post_id as course_id,
        author_user_id as instructor_user_id,
        post_status as course_status_code,
        post_title as course_title,
        post_excerpt as course_summary,
        post_slug as course_slug,
        posted_at as published_at,
        modified_at as updated_at
    from filtered
),

decoded as (
    select
        course_id,
        instructor_user_id,
        case course_status_code
            when 'publish' then 'Published'
            when 'draft' then 'Draft'
            when 'pending' then 'Pending Review'
            when 'private' then 'Private'
            when 'future' then 'Scheduled'
            else 'Unknown'
        end as course_status,
        course_title,
        course_summary,
        course_slug,
        published_at,
        updated_at
    from renamed
),

null_handled as (
    select
        course_id,
        coalesce(nullif(instructor_user_id, 0), -1) as instructor_user_id,   -- WordPress writes 0 for no author
        course_status,
        coalesce(nullif(trim(course_title), ''), 'Unknown') as course_title,
        coalesce(nullif(trim(course_summary), ''), 'Unknown') as course_summary,
        coalesce(nullif(trim(course_slug), ''), 'Unknown') as course_slug,
        published_at,
        updated_at
    from decoded
)

select * from null_handled
