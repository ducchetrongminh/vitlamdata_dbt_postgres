with

wp_user as (
    select
        -- Keys
        wp_user_id,
        -- Attributes
        registered_at
    from {{ ref('stg_wordpress__wp_user') }}
),

unknown_user as (
    select
        -- Keys
        -1 as wp_user_id,
        -- Attributes
        null::timestamp as registered_at
),

inserted_unknown as (
    select * from wp_user
    union all
    select * from unknown_user
)

select * from inserted_unknown
