{{ config(severity='warn') }}

-- wp_postmeta keys that match no pattern in wp_post_meta_key_allowlist.
-- stg_wordpress__wp_post_meta drops them, so nothing leaks; review each key,
-- then add it to the seed with its pii_indicator.

select distinct meta.meta_key
from {{ source('wordpress', 'wp_postmeta') }} as meta
where not exists (
    select 1
    from {{ ref('wp_post_meta_key_allowlist') }} as allowlist
    where meta.meta_key ~ allowlist.meta_key_pattern
)
