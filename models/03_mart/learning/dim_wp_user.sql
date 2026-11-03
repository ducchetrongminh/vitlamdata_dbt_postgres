with

wp_user as (
    select * from {{ ref('int_wp_user__inserted_inferred') }}
),

final as (
    select
        -- Keys
        {{ dbt_utils.generate_surrogate_key(['wp_user_id']) }} as wp_user_key,
        wp_user_id,
        -- Attributes
        wp_user_status,
        registered_at
    from wp_user
)

select * from final
