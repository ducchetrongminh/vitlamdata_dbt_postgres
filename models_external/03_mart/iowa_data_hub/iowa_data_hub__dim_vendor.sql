with

vendor as (
    select * from {{ ref('iowa_data_hub__int_vendor__latest_picked') }}
),

final as (
    select
        -- Keys
        {{ dbt_utils.generate_surrogate_key(['vendor_code']) }} as vendor_key,
        vendor_code,
        -- Name, desc
        vendor_name
    from vendor
)

select * from final
