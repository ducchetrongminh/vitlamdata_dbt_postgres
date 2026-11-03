-- Incremental with a 3-day lookback: lead posts never change after they are
-- created, but roadmap_sent_at (post meta) is written a few seconds after the lead,
-- and a meta update does not bump the post's modified time. Reprocessing the last
-- 3 days picks up a roadmap time that a load ran too early to see.
-- shortcut: a lead trashed in WordPress stays in this table; run --full-refresh to drop it
{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='wp_lead_id',
        on_schema_change='fail'
    )
}}

with

lead as (
    select * from {{ ref('int_wp_lead__meta_pivoted') }}
    {% if is_incremental() %}
    where submitted_at >= (select max(submitted_at) from {{ this }}) - interval '3 days'
    {% endif %}
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
