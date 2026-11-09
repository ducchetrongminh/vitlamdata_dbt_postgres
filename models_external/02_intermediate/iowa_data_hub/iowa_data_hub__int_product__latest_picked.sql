-- One row per item sold, from its latest sales line: the catalog lacks delisted items
-- (README Q1). Product is type 1, each item takes its latest values (README "Product
-- attributes are type 1", Q15: the latest bottle_volume_ml). The line's category code is
-- mapped and named later, in iowa_data_hub__int_product__category_picked.
-- README Q2: a line in TEMPORARY & SPECIALTY PACKAGES, or with no category (liquor_sales_2026.md
-- #4), loses to the item's other lines of the same year.
-- Why we don't follow docs/dbt-layers-conventions.md#31-intermediate-structural-constraints
-- (ephemeral by default): same reason and load rules as iowa_data_hub__int_store__latest_picked,
-- each run reads one year and merges its items in.
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='product_code',
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
        {{ iowa_data_hub_order_years() | last }}
    )
    {% else %}
    where order_year = {{ iowa_data_hub_order_years() | first }}
    {% endif %}
),

-- shortcut: the category preference picks the whole line, so an item whose latest lines are
-- TEMPORARY & SPECIALTY PACKAGES takes its name, pack and volume from an older line of the
-- year; and a year with only such lines overwrites the item's earlier real category. Split
-- the pick per attribute if that matters.
latest_picked as (
    select distinct on (product_code)
        -- Keys
        product_code,
        -- Name, desc
        product_name,
        -- Attributes
        pack,
        bottle_volume_ml,
        category_code,
        category_name as historic_category_name,
        -- Dates
        ordered_on,
        -- Load tracking
        order_year as last_order_year
    from order_line
    where product_code <> 'UNKNOWN'
    order by
        product_code,
        coalesce(category_name = 'TEMPORARY & SPECIALTY PACKAGES', false),
        category_code is null,
        ordered_on desc,
        product_name
),

cleaned as (
    select
        -- Keys
        product_code,
        -- Name, desc
        regexp_replace(trim(product_name), '\s{2,}', ' ', 'g') as product_name,   -- 2026 #9
        -- Attributes
        pack,
        nullif(bottle_volume_ml, 0) as bottle_volume_ml,   -- 2015 #3: 0 on 2 lines
        category_code,
        historic_category_name,
        -- Dates
        ordered_on,
        -- Load tracking
        last_order_year
    from latest_picked
),

null_handled as (
    select
        -- Keys
        product_code,
        -- Name, desc
        coalesce(nullif(product_name, ''), 'Unknown') as product_name,
        -- Attributes
        pack,
        bottle_volume_ml,
        category_code,
        coalesce(nullif(historic_category_name, ''), 'Unknown') as historic_category_name,
        -- Dates
        ordered_on,
        -- Load tracking
        last_order_year
    from cleaned
)

select * from null_handled
