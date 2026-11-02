with

wp_user as (
    select * from {{ ref('stg_wordpress__wp_user') }}
),

instructor_allowlist as (
    select * from {{ ref('wp_instructor_allowlist') }}
),

instructor as (
    select
        -- Keys
        wp_user.wp_user_id as wp_instructor_id,
        -- Name, desc
        coalesce(wp_user.wp_user_public_name, 'Unknown') as wp_instructor_name
    from wp_user
    inner join instructor_allowlist on wp_user.wp_user_id = instructor_allowlist.wp_user_id
),

unknown_instructor as (
    select
        -- Keys
        -1 as wp_instructor_id,
        -- Name, desc
        'Unknown' as wp_instructor_name
),

inserted_unknown as (
    select * from instructor
    union all
    select * from unknown_instructor
)

select * from inserted_unknown
