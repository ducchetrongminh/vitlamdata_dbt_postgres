-- Cleanup per docs/profiling/iowa_data_hub/liquor_sales_2026.md (issues #n), the reference
-- for every year, and _README.md (Qn).
-- One model for all year tables: the publisher splits one table (liquor_sales_combined) by
-- year, so every year has the same columns and grain. Add each new year to the list.
-- Why we don't follow docs/dbt-layers-conventions.md#21-staging-structural-constraints
-- (staging is always a view, a table only when the view is too slow): deduplicating ~38M
-- lines takes minutes, so as a view every reader repeats it, and as a table every run does.
-- Workaround: past years load once and never change (README); only the latest year reloads.
-- So the model is incremental, and a normal run replaces only the latest year's lines
-- (delete+insert on order_year). --full-refresh rebuilds every year.
-- When a new year starts, add it to the range and run --full-refresh once: the year before
-- may have changed in its last reloads.
{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key='order_year',
    on_schema_change='fail'
) }}

{%- set years = range(2012, 2027) | list %}
{%- set latest_year = years | last %}

with

source as (
    {%- for year in years if not is_incremental() or year == latest_year %}
    select *, {{ year }} as order_year from {{ source('iowa_data_hub', 'liquor_sales_' ~ year) }}
    {%- if not loop.last %}
    union all
    {%- endif %}
    {%- endfor %}
),

filtered as (
    select distinct * from source       -- Q9: drop whole-row repeats
),

renamed as (
    select
        -- Keys
        -- Q8: invoice_id holds the line number up to 2025-08-29; after, only a hash of
        -- the whole row tells lines apart
        case
            when ordered_on <= '2025-08-29' then invoice_id
            else md5(filtered::text)
        end as order_line_id,
        store_no as store_code,
        -- Dates
        ordered_on,
        order_year,
        -- Store attributes
        store_name,
        store_city,
        store_zip_code,
        county_fips_code,
        county_name
    from filtered
),

casted as (
    select
        -- Keys
        cast(order_line_id as text) as order_line_id,
        cast(store_code as text) as store_code,
        -- Dates
        cast(ordered_on as date) as ordered_on,
        cast(order_year as integer) as order_year,
        -- Store attributes
        cast(store_name as text) as store_name,
        cast(store_city as text) as store_city,
        cast(store_zip_code as text) as store_zip_code,
        cast(county_fips_code as text) as county_fips_code,
        cast(county_name as text) as county_name
    from renamed
),

cleaned as (
    select
        -- Keys
        order_line_id,
        store_code,
        -- Dates
        ordered_on,
        order_year,
        -- Store attributes
        regexp_replace(trim(store_name), '\s{2,}', ' ', 'g') as store_name,   -- #9
        store_city,
        case                                                -- Q12: Bettendorf zip typo
            when store_code = '2687' and store_zip_code = '57222' then '52722'
            else store_zip_code
        end as store_zip_code,
        county_fips_code,
        county_name
    from casted
),

null_handled as (
    select
        -- Keys
        order_line_id,
        coalesce(nullif(store_code, ''), 'UNKNOWN') as store_code,
        -- Dates
        ordered_on,
        order_year,
        -- Store attributes; #5: the location columns are null together on some lines
        coalesce(nullif(store_name, ''), 'Unknown') as store_name,
        coalesce(nullif(store_city, ''), 'Unknown') as store_city,
        coalesce(nullif(store_zip_code, ''), 'Unknown') as store_zip_code,
        coalesce(nullif(county_fips_code, ''), 'Unknown') as county_fips_code,
        coalesce(nullif(county_name, ''), 'Unknown') as county_name
    from cleaned
)

select * from null_handled
