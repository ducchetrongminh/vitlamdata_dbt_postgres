-- Cleanup per docs/profiling/iowa_data_hub/liquor_sales_2026.md (issues #n), the reference
-- for every year, and _README.md (Qn).
-- One model for all year tables: the publisher splits one table (liquor_sales_combined) by
-- year, so every year has the same columns and grain. The years are listed in
-- macro iowa_data_hub_order_years.
-- Keeps the export's whole-row repeats (README Q9): dropping them needs a sort of every
-- line, so iowa_data_hub__int_order_line__deduplicated does it, for the models that need it.
-- The store and vendor attributes ride on each line only because the source has no store or
-- vendor table. They pass through as loaded: iowa_data_hub__int_store__latest_picked and
-- iowa_data_hub__int_vendor__latest_picked clean them.
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
        vendor_name
    from source
),

casted as (
    select
        -- Keys
        cast(order_line_id as text) as order_line_id,
        cast(store_code as text) as store_code,
        cast(vendor_code as text) as vendor_code,
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
        cast(vendor_name as text) as vendor_name
    from renamed
),

cleaned as (
    select
        -- Keys
        order_line_id,
        store_code,
        lpad(vendor_code, 3, '0') as vendor_code,         -- 2016 #1: 2 digits before 2016-08-29
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
        vendor_name
    from casted
),

-- Keys only: the store and vendor attributes are cleaned in their dims' intermediate models
null_handled as (
    select
        -- Keys
        order_line_id,
        coalesce(nullif(store_code, ''), 'UNKNOWN') as store_code,
        coalesce(nullif(vendor_code, ''), 'UNKNOWN') as vendor_code,  -- 2021 #1
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
        vendor_name
    from cleaned
)

select * from null_handled
