-- Ephemeral, not a view: post_title is raw PII for leads (vld_lead titles are the
-- lead's email), so this model is never stored. Staging models on top of it pick
-- their post type and hash what they need.
{{ config(materialized='ephemeral') }}

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
        -- Keys
        id as wp_post_id,
        -- Name, desc
        post_title as wp_post_title,
        post_excerpt as wp_post_excerpt,
        -- Attributes
        post_type as wp_post_type,
        post_status as wp_post_status,
        post_name as wp_post_slug,
        post_date_gmt as posted_at_utc,
        post_modified_gmt as modified_at_utc,
        -- Parent post
        post_parent as parent_wp_post_id,
        -- Author
        post_author as author_wp_user_id
    from filtered
),

casted as (
    select
        -- Keys
        cast(wp_post_id as bigint) as wp_post_id,
        -- Name, desc
        cast(wp_post_title as text) as wp_post_title,
        cast(wp_post_excerpt as text) as wp_post_excerpt,
        -- Attributes
        cast(wp_post_type as text) as wp_post_type,
        cast(wp_post_status as text) as wp_post_status,
        cast(wp_post_slug as text) as wp_post_slug,
        cast(posted_at_utc as timestamp) at time zone 'UTC' at time zone 'Asia/Ho_Chi_Minh' as posted_at,
        cast(modified_at_utc as timestamp) at time zone 'UTC' at time zone 'Asia/Ho_Chi_Minh' as modified_at,
        -- Parent post
        cast(parent_wp_post_id as bigint) as parent_wp_post_id,
        -- Author
        cast(author_wp_user_id as bigint) as author_wp_user_id
    from renamed
)

select * from casted
