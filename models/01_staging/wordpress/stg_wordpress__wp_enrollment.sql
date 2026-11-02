with

base as (
    select * from {{ ref('base_wordpress__wp_post') }}
),

filtered as (
    select * from base
    where wp_post_type = 'tutor_enrolled'
),

renamed as (
    select
        -- Keys
        wp_post_id as wp_enrollment_id,
        -- Foreign keys
        author_wp_user_id as student_wp_user_id,
        parent_wp_post_id as wp_course_id,
        -- Attributes
        wp_post_status as wp_enrollment_status_code,
        -- Dates
        posted_at as enrolled_at,
        modified_at as updated_at
    from filtered
),

decoded as (
    select
        *,
        case wp_enrollment_status_code
            when 'completed' then 'Enrolled'   -- Tutor's 'completed' means the enrollment went through, not that the course was finished
            when 'pending' then 'Pending'
            when 'cancel' then 'Cancelled'
            else 'Unknown'
        end as wp_enrollment_status
    from renamed
),

null_handled as (
    select
        -- Keys
        wp_enrollment_id,
        -- Foreign keys
        coalesce(nullif(student_wp_user_id, 0), -1) as student_wp_user_id,
        coalesce(nullif(wp_course_id, 0), -1) as wp_course_id,
        -- Attributes
        wp_enrollment_status,
        -- Dates
        enrolled_at,
        updated_at
    from decoded
)

select * from null_handled
