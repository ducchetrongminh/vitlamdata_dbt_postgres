-- One row per vendor, built from the sales lines: the vendor applied at the order, which can
-- differ from the catalog's. Vendor is type 1: each vendor takes its latest line's name
-- (docs/profiling/iowa_data_hub/liquor_sales_2025.md #6), so names from the system before
-- 2016-08-29 give way to the later ones (liquor_sales_2016.md #1).
-- Why we don't follow docs/dbt-layers-conventions.md#31-intermediate-structural-constraints
-- (ephemeral by default): same reason and load rules as iowa_data_hub__int_store__latest_picked,
-- each run reads one year and merges its vendors in.
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='vendor_code',
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

latest_picked as (
    select distinct on (vendor_code)
        -- Keys
        vendor_code,
        -- Name, desc
        vendor_name,
        -- Load tracking
        order_year as last_order_year
    from order_line
    order by vendor_code, ordered_on desc, vendor_name
),

unknown_vendor as (
    select
        -- Keys
        'UNKNOWN' as vendor_code,
        -- Name, desc
        'Unknown' as vendor_name,
        -- Load tracking
        null::integer as last_order_year
),

inserted_unknown as (
    select * from latest_picked
    where vendor_code <> 'UNKNOWN'
    union all
    select * from unknown_vendor
)

select * from inserted_unknown
