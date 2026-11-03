-- A table, not incremental: roadmap_sent_at lives in wp_postmeta, and a meta update
-- does not bump the lead post's modified time, so there is no reliable cursor.

with

lead as (
    select * from {{ ref('int_wp_lead__meta_pivoted') }}
),

final as (
    select
        -- Keys
        wp_lead_id,
        -- Attributes
        wp_lead_source,
        -- Dates
        submitted_at,
        roadmap_sent_at
    from lead
)

select * from final
