with

vendor as (
    select * from {{ ref('iowa_data_hub__int_vendor__current_named') }}
),

final as (
    select
        -- Keys
        {{ dbt_utils.generate_surrogate_key(['vendor_code']) }} as vendor_key,
        vendor_code,
        -- Name, desc
        historic_vendor_name,
        current_vendor_name
    from vendor
)

select * from final
