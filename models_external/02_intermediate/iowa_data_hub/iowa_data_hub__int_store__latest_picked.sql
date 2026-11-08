-- One row per store, built from the sales lines: there is no store table. Store is type 1:
-- each store takes its latest name (README Q14) and its latest known location
-- (docs/profiling/iowa_data_hub/liquor_sales_2026.md #5).
with

order_line as (
    select * from {{ ref('stg_iowa_data_hub__liquor_order_line') }}
),

store_version as (
    select
        store_code,
        store_name,
        store_city,
        store_zip_code,
        county_fips_code,
        county_name,
        max(ordered_on) as last_ordered_on
    from order_line
    group by 1, 2, 3, 4, 5, 6
),

latest_name as (
    select distinct on (store_code)
        store_code,
        store_name
    from store_version
    order by store_code, last_ordered_on desc, store_name
),

-- #5: some lines lack the location (null together); a store keeps it from its other lines
latest_location as (
    select distinct on (store_code)
        store_code,
        store_city,
        store_zip_code,
        county_fips_code,
        county_name
    from store_version
    where county_fips_code <> 'Unknown'
    order by store_code, last_ordered_on desc, store_zip_code
),

latest_picked as (
    select
        -- Keys
        latest_name.store_code,
        -- Name, desc
        latest_name.store_name,
        -- Attributes; store 010206 has no location on any line
        coalesce(latest_location.store_city, 'Unknown') as store_city,
        coalesce(latest_location.store_zip_code, 'Unknown') as store_zip_code,
        coalesce(latest_location.county_fips_code, 'Unknown') as county_fips_code,
        coalesce(latest_location.county_name, 'Unknown') as county_name
    from latest_name
    left join latest_location on latest_name.store_code = latest_location.store_code
),

unknown_store as (
    select
        -- Keys
        'UNKNOWN' as store_code,
        -- Name, desc
        'Unknown' as store_name,
        -- Attributes
        'Unknown' as store_city,
        'Unknown' as store_zip_code,
        'Unknown' as county_fips_code,
        'Unknown' as county_name
),

inserted_unknown as (
    select * from latest_picked
    where store_code <> 'UNKNOWN'
    union all
    select * from unknown_store
)

select * from inserted_unknown
