with

base as (
    select * from {{ ref('base_wordpress__wp_user') }}
),

final as (
    select
        -- Keys
        wp_user_id,
        -- Attributes
        registered_at
    from base
)

select * from final
