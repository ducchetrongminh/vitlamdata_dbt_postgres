-- One row per store, built from the sales lines: there is no store table. Store is type 1:
-- each store takes its latest name (README Q14) and its latest known location
-- (docs/profiling/iowa_data_hub/liquor_sales_2026.md #5).
-- Why we don't follow docs/dbt-layers-conventions.md#31-intermediate-structural-constraints
-- (ephemeral by default): it groups ~38M lines. Past years load once and never change
-- (README); only the latest year reloads. So a normal run reads only the years from the
-- latest one already stored (order_year >= last_order_year; the base view then skips
-- the other year tables) and merges those stores in. --full-refresh reads every year.
-- Why we don't follow docs/dbt-layers-conventions.md#51-one-directional-layering (only a
-- staging model reads a base model): the store reads the order lines before the repeats
-- are dropped. Repeats cannot change a store's latest name or location, and dropping them
-- over every year ran the database out of temp disk.
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='store_code',
    on_schema_change='fail'
) }}

with

order_line as (
    select * from {{ ref('base_iowa_data_hub__liquor_order_line') }}
    {% if is_incremental() %}
    -- from the latest stored year, not only the newest: when a year starts, the year
    -- before still gets its last reloads
    where order_year >= (select max(last_order_year) from {{ this }})
    {% endif %}
),

store_version as (
    select
        store_code,
        store_name,
        store_city,
        store_zip_code,
        county_fips_code,
        county_name,
        max(ordered_on) as last_ordered_on,
        max(order_year) as last_order_year
    from order_line
    group by 1, 2, 3, 4, 5, 6
),

latest_name as (
    select distinct on (store_code)
        store_code,
        store_name,
        last_order_year
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

-- On an incremental run, a store whose new lines all lack the location keeps the stored one
stored_location as (
    {% if is_incremental() %}
    select store_code, store_city, store_zip_code, county_fips_code, county_name
    from {{ this }}
    where county_fips_code <> 'Unknown'
    {% else %}
    select
        null::text as store_code,
        null::text as store_city,
        null::text as store_zip_code,
        null::text as county_fips_code,
        null::text as county_name
    where false
    {% endif %}
),

latest_picked as (
    select
        -- Keys
        latest_name.store_code,
        -- Name, desc
        latest_name.store_name,
        -- Attributes; store 010206 has no location on any line
        coalesce(latest_location.store_city, stored_location.store_city, 'Unknown') as store_city,
        coalesce(latest_location.store_zip_code, stored_location.store_zip_code, 'Unknown')
            as store_zip_code,
        coalesce(latest_location.county_fips_code, stored_location.county_fips_code, 'Unknown')
            as county_fips_code,
        coalesce(latest_location.county_name, stored_location.county_name, 'Unknown')
            as county_name,
        -- Load tracking
        latest_name.last_order_year
    from latest_name
    left join latest_location on latest_name.store_code = latest_location.store_code
    left join stored_location on latest_name.store_code = stored_location.store_code
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
        'Unknown' as county_name,
        -- Load tracking
        null::integer as last_order_year
),

inserted_unknown as (
    select * from latest_picked
    where store_code <> 'UNKNOWN'
    union all
    select * from unknown_store
)

select * from inserted_unknown
