with

source as (
    select * from {{ source('wordpress', 'wp_postmeta') }}
),

allowlist as (
    select * from {{ ref('wp_post_meta_key_allowlist') }}
),

filtered as (
    -- keep only reviewed keys; a new key stays out until it is added to the allowlist
    select * from source
    where exists (
        select 1 from allowlist
        where source.meta_key ~ allowlist.meta_key_pattern
    )
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
    from filtered
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
),

hashed as (
    select
        -- Keys
        wp_post_meta_id,
        -- Foreign keys
        wp_post_id,
        -- Attributes
        meta_key,
        case
            when exists (
                select 1 from allowlist
                where casted.meta_key ~ allowlist.meta_key_pattern
                    and allowlist.pii_indicator = 'PII'
            ) then {{ hash_pii('meta_value') }}
            else meta_value
        end as meta_value
    from casted
)

select * from hashed
