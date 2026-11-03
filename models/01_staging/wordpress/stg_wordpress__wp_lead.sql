with

base as (
    select * from {{ ref('base_wordpress__wp_post') }}
),

filtered as (
    select * from base
    where wp_post_type = 'vld_lead'
),

renamed as (
    -- post_title is the lead's email: not selected until a model needs it (then hashed)
    select
        -- Keys
        wp_post_id as wp_lead_id,
        -- Dates
        posted_at as submitted_at
    from filtered
)

select * from renamed
