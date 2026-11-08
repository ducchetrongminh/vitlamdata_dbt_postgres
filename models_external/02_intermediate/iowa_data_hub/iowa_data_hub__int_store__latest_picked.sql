-- One row per store, built from the sales lines: there is no store table. Store is type 1:
-- each store takes its latest line's name (README Q14) and location. A line can lack the
-- location (docs/profiling/iowa_data_hub/liquor_sales_2026.md #5), but only for a while,
-- before it is entered, so the latest line is trusted: such a store shows 'Unknown' until
-- it orders again.
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

-- On the latest day, a line with the location wins over one without
latest_picked as (
    select distinct on (store_code)
        -- Keys
        store_code,
        -- Name, desc
        store_name,
        -- Attributes
        store_city,
        store_zip_code,
        county_fips_code,
        county_name,
        -- Load tracking
        order_year as last_order_year
    from order_line
    order by store_code, ordered_on desc, county_fips_code = 'Unknown', store_name
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
