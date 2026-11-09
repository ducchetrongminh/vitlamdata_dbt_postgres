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

renamed as (
    select
        -- Keys
        -- Q8: invoice_id holds the line number up to 2025-08-29; after, only a hash of
        -- the whole row tells lines apart
        case
            when ordered_on <= '2025-08-29' then invoice_id
            else md5(source::text)
        end as order_line_id,
        store_no as store_code,
        vendor_number as vendor_code,
        item_no as product_code,
        -- Dates
        ordered_on,
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
        category_name
    from source
),

casted as (
    select
        -- Keys
        cast(order_line_id as text) as order_line_id,
        cast(store_code as text) as store_code,
        cast(vendor_code as text) as vendor_code,
        cast(product_code as text) as product_code,
        -- Dates
        cast(ordered_on as date) as ordered_on,
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
        cast(category_name as text) as category_name
    from renamed
),

cleaned as (
    select
        -- Keys
        order_line_id,
        store_code,
        vendor_code,
        product_code,
        -- Dates
        ordered_on,
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
        category_name
    from casted
),

-- Keys only: the attributes are cleaned in their dims' intermediate models
null_handled as (
    select
        -- Keys
        order_line_id,
        coalesce(nullif(store_code, ''), 'UNKNOWN') as store_code,
        coalesce(nullif(vendor_code, ''), 'UNKNOWN') as vendor_code,  -- 2021 #1
        coalesce(nullif(product_code, ''), 'UNKNOWN') as product_code,
        -- Dates
        ordered_on,
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
        category_name
    from cleaned
)

select * from null_handled
