-- Cleanup per docs/profiling/iowa_data_hub/liquor_sales_2026.md (issues #n), the reference
-- for every year, and _README.md (Qn).
-- One model for all year tables: the publisher splits one table (liquor_sales_combined) by
-- year, so every year has the same columns and grain. The years are listed in
-- macro iowa_data_hub_order_years.
-- Keeps the export's whole-row repeats (README Q9): dropping them needs a sort of every
-- line, so iowa_data_hub__int_order_line__deduplicated does it, for the models that need it.
-- The store, vendor, product and category attributes ride on each line: the source has no
-- store or vendor table, and the catalog lacks delisted items and category codes. They pass
-- through as loaded; each dim's intermediate model cleans them.
-- Why we don't follow docs/dbt-layers-conventions.md#23-value-level-transformations
-- (cleanup and null handling in staging): they are another entity's attributes, and each
-- dim keeps one line per entity, so cleaning there runs on a few thousand rows, not ~38M.
-- order_year is a constant in each part of the union, so a filter on it skips the other
-- years' tables without reading them.
{%- set years = iowa_data_hub_order_years() %}

with

source as (
    {%- for year in years %}
    select *, {{ year }} as order_year
    from {{ source('iowa_data_hub', 'liquor_sales_' ~ year) }}
    {%- if not loop.last %}
    union all
    {%- endif %}
    {%- endfor %}
),

-- README Q20, liquor_sales_2013 #2: item 3984's 2013 lines are billed about ten times its
-- price, $820,193 in all, so they are dropped
filtered as (
    select * from source
    where item_no is distinct from '3984' or order_year <> 2013
),

renamed as (
    select
        -- Keys
        -- Q8: invoice_id holds the line number up to 2025-08-29; after, only a hash of
        -- the whole row tells lines apart
        case
            when ordered_on <= '2025-08-29' then invoice_id
            else md5(filtered::text)
        end as order_line_no,
        invoice_id,
        store_no as store_code,
        vendor_number as vendor_code,
        item_no as product_code,
        -- Dates
        ordered_on as order_date,
        order_year,
        -- Store attributes
        store_name,
        store_city,
        store_zip_code,
        county_fips_code,
        county_name,
        -- Vendor attributes
        vendor_name,
        -- Product attributes
        im_desc as product_name,
        pack,
        bottle_volume_ml,
        category_code,
        category_name,
        -- Measures
        sales_bottles as bottle_qty,
        sales_dollars as order_amt,
        state_bottle_cost as state_bottle_cost_unit_price,
        state_bottle_retail as state_bottle_retail_unit_price
    from filtered
),

casted as (
    select
        -- Keys
        cast(order_line_no as text) as order_line_no,
        cast(invoice_id as text) as invoice_id,
        cast(store_code as text) as store_code,
        cast(vendor_code as text) as vendor_code,
        cast(product_code as text) as product_code,
        -- Dates
        cast(order_date as date) as order_date,
        cast(order_year as integer) as order_year,
        -- Store attributes
        cast(store_name as text) as store_name,
        cast(store_city as text) as store_city,
        cast(store_zip_code as text) as store_zip_code,
        cast(county_fips_code as text) as county_fips_code,
        cast(county_name as text) as county_name,
        -- Vendor attributes
        cast(vendor_name as text) as vendor_name,
        -- Product attributes
        cast(product_name as text) as product_name,
        cast(pack as integer) as pack,
        cast(bottle_volume_ml as integer) as bottle_volume_ml,
        cast(category_code as text) as category_code,
        cast(category_name as text) as category_name,
        -- Measures
        cast(bottle_qty as integer) as bottle_qty,
        cast(order_amt as numeric) as order_amt,
        cast(state_bottle_cost_unit_price as numeric) as state_bottle_cost_unit_price,
        cast(state_bottle_retail_unit_price as numeric) as state_bottle_retail_unit_price
    from renamed
),

decoded as (
    select
        *,
        -- README Q8: up to 2025-08-29 the id ends in a 5-digit line number; after, it is the
        -- invoice alone. The invoice is unique only with store and date.
        case
            when order_date <= '2025-08-29' then left(invoice_id, -5)
            else invoice_id
        end as invoice_no,
        case when invoice_id like 'R%' then 'Return' else 'Order' end as invoice_type  -- Q8, 2026 #7
    from casted
),

-- Keys only: the attributes are cleaned in their dims' intermediate models
null_handled as (
    select
        -- Keys
        order_line_no,
        invoice_no,
        coalesce(nullif(store_code, ''), 'UNKNOWN') as store_code,
        coalesce(nullif(vendor_code, ''), 'UNKNOWN') as vendor_code,  -- 2021 #1
        coalesce(nullif(product_code, ''), 'UNKNOWN') as product_code,
        -- Dates
        order_date,
        order_year,
        -- Store attributes
        store_name,
        store_city,
        store_zip_code,
        county_fips_code,
        county_name,
        -- Vendor attributes
        vendor_name,
        -- Product attributes
        product_name,
        pack,
        bottle_volume_ml,
        category_code,
        category_name,
        -- Attributes
        invoice_type,
        -- Measures
        bottle_qty,
        state_bottle_cost_unit_price,
        state_bottle_retail_unit_price,
        order_amt
    from decoded
),

-- Design "Facts": the state's cost of the bottles, NULL before 2025-07-01 like the cost
-- (liquor_sales_2025 #3)
derived as (
    select
        *,
        bottle_qty * state_bottle_cost_unit_price as state_cost_amt
    from null_handled
)

select * from derived
