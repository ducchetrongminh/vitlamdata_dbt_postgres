with

source as (
    select * from {{ source('wordpress', 'wp_postmeta') }}
),

renamed as (
    select
        -- Keys
        meta_id as wp_post_meta_id,
        -- Foreign keys
        post_id as wp_post_id,
        -- Attributes
        meta_key,
        meta_value
    from source
),

casted as (
    select
        -- Keys
        cast(wp_post_meta_id as bigint) as wp_post_meta_id,
        -- Foreign keys
        cast(wp_post_id as bigint) as wp_post_id,
        -- Attributes
        cast(meta_key as text) as meta_key,
        cast(meta_value as text) as meta_value   -- always text; cast each key where it is pivoted
    from renamed
)

select * from casted
