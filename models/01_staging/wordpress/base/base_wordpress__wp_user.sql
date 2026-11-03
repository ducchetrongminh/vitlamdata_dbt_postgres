-- Ephemeral, not a view: this model holds raw names, so it is never stored.
-- stg_wordpress__wp_user and stg_wordpress__wp_instructor read it.
{{ config(materialized='ephemeral') }}

with

source as (
    select * from {{ source('wordpress', 'wp_users') }}
),

renamed as (
    select
        -- Keys
        id as wp_user_id,
        -- Name, desc
        display_name as wp_user_display_name,
        -- Attributes
        user_registered as registered_at_utc
    from source
),

casted as (
    select
        -- Keys
        cast(wp_user_id as bigint) as wp_user_id,
        -- Name, desc
        cast(wp_user_display_name as text) as wp_user_display_name,
        -- Attributes
        cast(registered_at_utc as timestamp) at time zone 'UTC' at time zone 'Asia/Ho_Chi_Minh' as registered_at
    from renamed
)

select * from casted
