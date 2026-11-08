-- One row per store, built from the sales lines: there is no store table. Store is type 1:
-- each store takes its latest name (README Q14) and its latest known location
-- (docs/profiling/iowa_data_hub/liquor_sales_2026.md #5).
-- Why we don't follow docs/dbt-layers-conventions.md#31-intermediate-structural-constraints
-- (ephemeral by default): it groups ~38M lines, and reading every year in one query used
-- too much disk on the database VM. So each run reads one year (the staging view skips the
-- other year tables) and merges its stores in:
-- - a first build, or --full-refresh, reads the first year only;
-- - each later run reads the year after the latest stored one, so it catches up in one run
--   per year (15 runs for 2012-2026);
-- - once caught up, each run rereads the last year, the only one that reloads (README).
-- Reads staging, not int_order_line__deduplicated: repeats cannot change a store's latest
-- name or location, and dropping them over every year ran the database out of temp disk.
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='store_code',
    on_schema_change='fail'
) }}

with

order_line as (
    select * from {{ ref('stg_iowa_data_hub__liquor_order_line') }}
    {% if is_incremental() %}
    -- shortcut: when a new year is added, the run reads only that year, so the year before
    -- misses any reload after the last run; rerun it with --full-refresh and catch up if
    -- that matters.
    where order_year = least(
        (select max(last_order_year) from {{ this }}) + 1,
        {{ var('iowa_data_hub_last_order_year') }}
    )
    {% else %}
    where order_year = {{ var('iowa_data_hub_first_order_year') }}
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
