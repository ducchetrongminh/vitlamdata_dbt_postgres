-- Instructors whose display name is public on the course pages. Only these users
-- leave staging with an unhashed name. Add a wp_users.ID here after confirming the
-- name is published; a relationships test on dim_wp_course flags authors missing.
-- 2: author of courses 20 and 126 and bundle 292
{% set public_instructor_ids = [2] %}

with

base as (
    select * from {{ ref('base_wordpress__wp_user') }}
),

filtered as (
    select * from base
    where wp_user_id in ({{ public_instructor_ids | join(', ') }})
),

renamed as (
    select
        -- Keys
        wp_user_id as wp_instructor_id,
        -- Name, desc
        wp_user_display_name as wp_instructor_name
    from filtered
),

null_handled as (
    select
        -- Keys
        wp_instructor_id,
        -- Name, desc
        coalesce(nullif(trim(wp_instructor_name), ''), 'Unknown') as wp_instructor_name
    from renamed
)

select * from null_handled
