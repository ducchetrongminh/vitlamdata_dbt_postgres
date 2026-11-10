-- One row per category code seen on a sales line, with its latest name: the catalog has
-- names only, no codes. A code's name can change (docs/profiling/iowa_data_hub/
-- liquor_sales_2025.md #5: plural to singular on 2025-07-01), and an old code that kept its
-- number takes its new name (README Q21: 1031100 100 PROOF VODKA, now AMERICAN VODKAS).
-- Retired codes keep their own row; seed iowa_data_hub__legacy_category_map maps them.
-- Lines without a category (liquor_sales_2026.md #4) are left out.
-- Why we don't follow docs/dbt-layers-conventions.md#31-intermediate-structural-constraints
-- (ephemeral by default): same reason and load rules as iowa_data_hub__int_store__latest_picked,
-- each run reads one year and merges its codes in.
{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key='category_code',
    on_schema_change='fail'
) }}

with

order_line as (
    select * from {{ ref('stg_iowa_data_hub__liquor_order_line') }}
    {% if is_incremental() %}
    -- shortcut: when a new year is added, the run reads only that year, so the year before
    -- misses any reload after the last run; rerun it with --full-refresh and catch up if
    -- that matters.
    where
        order_year = least(
            (select max(this_run.last_order_year) from {{ this }} as this_run) + 1,
            {{ iowa_data_hub_order_years() | last }}
        )
    {% else %}
    where order_year = {{ iowa_data_hub_order_years() | first }}
    {% endif %}
),

latest_named as (
    select distinct on (category_code)
        -- Keys
        category_code,
        -- Name, desc
        category_name,
        -- Load tracking
        order_year as last_order_year
    from order_line
    where category_code is not null
    order by category_code, order_date desc, category_name
),

null_handled as (
    select
        -- Keys
        category_code,
        -- Name, desc
        coalesce(nullif(category_name, ''), 'Unknown') as category_name,
        -- Load tracking
        last_order_year
    from latest_named
)

select * from null_handled
