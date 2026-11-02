{{ config(severity='warn') }}

-- Authors of published courses and bundles missing from public_instructor_ids in
-- stg_wordpress__wp_instructor. Their courses point to an instructor with no row.
-- Confirm the name is public on the course page, then add the id to the list.

select distinct course.instructor_wp_user_id
from {{ ref('stg_wordpress__wp_course') }} as course
where
    course.wp_course_status = 'Published'
    and course.instructor_wp_user_id <> -1
    and course.instructor_wp_user_id not in (
        select wp_instructor_id from {{ ref('stg_wordpress__wp_instructor') }}
    )
