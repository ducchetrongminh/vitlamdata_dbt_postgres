with

instructor as (
    select * from {{ ref('int_wp_instructor__inserted_unknown') }}
),

final as (
    select
        -- Keys
        {{ dbt_utils.generate_surrogate_key(['wp_instructor_id']) }} as wp_instructor_key,
        wp_instructor_id,
        -- Name, desc
        wp_instructor_name
    from instructor
)

select * from final
