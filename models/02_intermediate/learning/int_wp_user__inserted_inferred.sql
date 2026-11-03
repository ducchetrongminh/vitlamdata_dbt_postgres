with

wp_user as (
    select
        -- Keys
        wp_user_id,
        -- Attributes
        'Active' as wp_user_status,
        registered_at
    from {{ ref('stg_wordpress__wp_user') }}
),

referenced_user as (
    -- user ids that facts point to; add each new fact's user column here
    select student_wp_user_id as wp_user_id from {{ ref('stg_wordpress__wp_enrollment') }}
),

inferred_user as (
    -- referenced but missing from wp_users. IDs are auto-increment, so an id below the
    -- current max existed and was deleted; an id above it was created after wp_users
    -- was loaded and arrives with the next load.
    -- shortcut: assumes ids are never reused or imported out of order; switch to a
    -- wp_users snapshot ("seen before" = deleted) once the snapshots schema exists (#22)
    select distinct
        -- Keys
        referenced_user.wp_user_id,
        -- Attributes
        case
            when referenced_user.wp_user_id < (select max(wp_user_id) from wp_user) then 'Deleted'
            else 'Not Loaded Yet'
        end as wp_user_status,
        null::timestamp as registered_at
    from referenced_user
    where
        referenced_user.wp_user_id <> -1
        and not exists (
            select 1 from wp_user
            where wp_user.wp_user_id = referenced_user.wp_user_id
        )
),

unknown_user as (
    select
        -- Keys
        -1 as wp_user_id,
        -- Attributes
        'Unknown' as wp_user_status,
        null::timestamp as registered_at
),

inserted_inferred as (
    select * from wp_user
    union all
    select * from inferred_user
    union all
    select * from unknown_user
)

select * from inserted_inferred
