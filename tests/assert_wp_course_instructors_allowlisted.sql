{{ config(severity='warn') }}

-- Course authors missing from wp_instructor_allowlist. Their name stays hashed, so
-- dim_wp_instructor shows them without a name. Confirm the name is public on the
-- course page, then add the wp_user_id to the seed.

select distinct course.instructor_wp_user_id
from {{ ref('stg_wordpress__wp_course') }} as course
where
    course.instructor_wp_user_id <> -1
    and not exists (
        select 1
        from {{ ref('wp_instructor_allowlist') }} as allowlist
        where allowlist.wp_user_id = course.instructor_wp_user_id
    )
