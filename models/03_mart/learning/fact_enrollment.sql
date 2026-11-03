{{
    config(
        materialized='incremental',
        incremental_strategy='delete+insert',
        unique_key='wp_enrollment_id',
        on_schema_change='append_new_columns'
    )
}}

with

enrollment as (
    select * from {{ ref('stg_wordpress__wp_enrollment') }}
    {% if is_incremental() %}
    where updated_at >= (select max(updated_at) from {{ this }})
    {% endif %}
),

final as (
    select
        -- Keys
        wp_enrollment_id,
        -- Foreign keys
        student_wp_user_id,
        wp_course_id,
        -- Attributes
        wp_enrollment_status,
        -- Foreign keys
        {{ dbt_utils.generate_surrogate_key(['student_wp_user_id']) }} as student_wp_user_key,
        {{ dbt_utils.generate_surrogate_key(['wp_course_id']) }} as wp_course_key,
        -- Dates
        enrolled_at,
        updated_at
    from enrollment
)

select * from final
