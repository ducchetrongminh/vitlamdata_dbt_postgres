-- Why we don't follow docs/dbt-layers-conventions.md#41-mart-structural-constraints
-- (incremental filter on the max updated timestamp): the source has no updated timestamp, and
-- one run over every year's ~38M lines needs a sort of them all to drop the repeats, which ran
-- the database VM out of temp disk (README Q9). So each run reads one year, the one after the
-- latest in the table, and replaces that year's dates (delete+insert, so a line gone from a
-- reloaded year goes too); a full refresh reads the first year. The order_date index serves
-- the latest-year lookup and the delete.
{{ config(
    alias='fact_liquor_order_line',
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='order_date',
    on_schema_change='fail',
    indexes=[{'columns': ['order_date']}]
) }}

with

order_line as (
    select * from {{ ref('iowa_data_hub__int_order_line__joined_to_product') }}
    {% if is_incremental() %}
    -- shortcut: when a new year is added, the run reads only that year, so the year before
    -- misses any reload after the last run; rerun it with --full-refresh and catch up if
    -- that matters. Each year table holds only its year's dates, so the latest date's year
    -- is the latest year loaded.
    where order_year = least(
        (select extract(year from max(order_date))::integer from {{ this }}) + 1,
        {{ iowa_data_hub_order_years() | last }}
    )
    {% else %}
    where order_year = {{ iowa_data_hub_order_years() | first }}
    {% endif %}
),

final as (
    select
        -- Keys
        order_line_no,
        invoice_no,
        -- Attributes
        invoice_type,
        -- Foreign keys
        {{ dbt_utils.generate_surrogate_key(['store_code']) }} as store_key,
        {{ dbt_utils.generate_surrogate_key(['product_code']) }} as product_key,
        {{ dbt_utils.generate_surrogate_key(['vendor_code']) }} as vendor_key,
        -- Dates
        order_date,
        -- Measures
        bottle_qty,
        liter_qty,
        state_bottle_cost_unit_price,
        state_bottle_retail_unit_price,
        order_amt,
        state_cost_amt
    from order_line
)

select * from final
