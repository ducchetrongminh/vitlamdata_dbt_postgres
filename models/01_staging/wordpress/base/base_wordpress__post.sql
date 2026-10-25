with

source as (
    select * from {{ source('wordpress', 'wp_posts') }}
),

filtered as (
    select * from source
    where post_status not in ('trash', 'auto-draft')
),

renamed as (
    select
        id as post_id,
        post_author as author_user_id,
        post_type,
        post_status,
        post_title,
        post_excerpt,
        post_name as post_slug,
        post_parent as parent_post_id,
        menu_order,
        post_date_gmt as posted_at_utc,
        post_modified_gmt as modified_at_utc
    from filtered
),

casted as (
    select
        cast(post_id as bigint) as post_id,
        cast(author_user_id as bigint) as author_user_id,
        cast(post_type as text) as post_type,
        cast(post_status as text) as post_status,
        cast(post_title as text) as post_title,
        cast(post_excerpt as text) as post_excerpt,
        cast(post_slug as text) as post_slug,
        cast(parent_post_id as bigint) as parent_post_id,
        cast(menu_order as integer) as menu_order,
        cast(posted_at_utc as timestamp) at time zone 'UTC' at time zone 'Asia/Ho_Chi_Minh' as posted_at,
        cast(modified_at_utc as timestamp) at time zone 'UTC' at time zone 'Asia/Ho_Chi_Minh' as modified_at
    from renamed
)

select * from casted
