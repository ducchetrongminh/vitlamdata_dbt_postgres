-- One row per vendor code, built from the sales lines: the vendor applied at the order, which can
-- differ from the catalog's. Vendor is type 1: each vendor takes its latest line's name
-- (docs/profiling/iowa_data_hub/liquor_sales_2025.md #6). A code of the system before
-- 2016-08-29 (10) keeps its own row and name; iowa_data_hub__int_vendor__current_named gives
-- it the name of its later code (010). Cleans the name after
-- picking, on one row per vendor: staging passes it as loaded.
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
        (select max(this_run.last_order_year) from {{ this }} as this_run) + 1,
        {{ iowa_data_hub_order_years() | last }}
    )
    {% else %}
    where order_year = {{ iowa_data_hub_order_years() | first }}
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
    order by vendor_code, order_date desc, vendor_name
),

cleaned as (
    select
        -- Keys
        vendor_code,
        -- Name, desc; #9: squeeze spaces; liquor_sales_2016.md #2: the É of RÉMY lost in encoding
        replace(regexp_replace(trim(vendor_name), '\s{2,}', ' ', 'g'), U&'\FFFD', 'É') as vendor_name,
        -- Load tracking
        last_order_year
    from latest_picked
),

null_handled as (
    select
        -- Keys
        vendor_code,
        -- Name, desc
        coalesce(nullif(vendor_name, ''), 'Unknown') as vendor_name,
        -- Load tracking
        last_order_year
    from cleaned
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
    select * from null_handled
    where vendor_code <> 'UNKNOWN'
    union all
    select * from unknown_vendor
)

select * from inserted_unknown
