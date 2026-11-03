with

lead as (
    select * from {{ ref('stg_wordpress__wp_lead') }}
),

post_meta as (
    select * from {{ ref('stg_wordpress__wp_post_meta') }}
),

pivoted as (
    select
        -- Keys
        lead.wp_lead_id,
        -- Attributes
        max(post_meta.meta_value) filter (where post_meta.meta_key = 'source') as wp_lead_source_code,
        -- Dates
        lead.submitted_at,
        max(post_meta.meta_value) filter (where post_meta.meta_key = 'roadmap_sent_at') as roadmap_sent_at_unix
    from lead
    left join post_meta on lead.wp_lead_id = post_meta.wp_post_id
    group by lead.wp_lead_id, lead.submitted_at
),

casted as (
    select
        -- Keys
        wp_lead_id,
        -- Attributes
        wp_lead_source_code,
        -- Dates
        submitted_at,
        to_timestamp(cast(nullif(trim(roadmap_sent_at_unix), '') as bigint)) at time zone 'Asia/Ho_Chi_Minh' as roadmap_sent_at
    from pivoted
),

decoded as (
    select
        *,
        case wp_lead_source_code
            when 'home-lead-magnet' then 'Home Lead Magnet'
            else 'Unknown'
        end as wp_lead_source
    from casted
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
    from decoded
)

select * from final
