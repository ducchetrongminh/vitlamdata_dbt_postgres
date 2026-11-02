with

instructor as (
    select * from {{ ref('stg_wordpress__wp_instructor') }}
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
