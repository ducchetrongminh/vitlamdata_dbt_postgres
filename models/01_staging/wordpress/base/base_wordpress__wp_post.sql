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
        id as wp_post_id,
        post_author as author_wp_user_id,
        post_type as wp_post_type,
        post_status as wp_post_status,
        post_title as wp_post_title,
        post_excerpt as wp_post_excerpt,
        post_name as wp_post_slug,
        post_parent as parent_wp_post_id,
        menu_order as wp_post_menu_order,
        post_date_gmt as posted_at_utc,
        post_modified_gmt as modified_at_utc
    from filtered
),

casted as (
    select
        cast(wp_post_id as bigint) as wp_post_id,
        cast(author_wp_user_id as bigint) as author_wp_user_id,
        cast(wp_post_type as text) as wp_post_type,
        cast(wp_post_status as text) as wp_post_status,
        cast(wp_post_title as text) as wp_post_title,
        cast(wp_post_excerpt as text) as wp_post_excerpt,
        cast(wp_post_slug as text) as wp_post_slug,
        cast(parent_wp_post_id as bigint) as parent_wp_post_id,
        cast(wp_post_menu_order as integer) as wp_post_menu_order,
        cast(posted_at_utc as timestamp) at time zone 'UTC' at time zone 'Asia/Ho_Chi_Minh' as posted_at,
        cast(modified_at_utc as timestamp) at time zone 'UTC' at time zone 'Asia/Ho_Chi_Minh' as modified_at
    from renamed
)

select * from casted
