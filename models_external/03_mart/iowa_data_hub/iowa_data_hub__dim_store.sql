with

store as (
    select * from {{ ref('iowa_data_hub__int_store__latest_picked') }}
),

final as (
    select
        -- Keys
        {{ generate_bigint_surrogate_key(['store_code']) }} as store_key,
        store_code,
        -- Name, desc
        store_name,
        -- Attributes
        store_city,
        store_zip_code,
        county_fips_code,
        county_name
    from store
)

select * from final
