-- Cleanup per docs/profiling/iowa_data_hub/liquor_sales_2026.md (issues #n), the reference
-- for every year, and _README.md (Qn).
-- One model for all year tables: the publisher splits one table (liquor_sales_combined) by
-- year, so every year has the same columns and grain. Add a year here when it is in scope.
with

source as (
    select * from {{ source('iowa_data_hub', 'liquor_sales_2025') }}
    union all
    select * from {{ source('iowa_data_hub', 'liquor_sales_2026') }}
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
        -- Store attributes; #5: the location columns are null together on some lines
        coalesce(nullif(store_name, ''), 'Unknown') as store_name,
        coalesce(nullif(store_city, ''), 'Unknown') as store_city,
        coalesce(nullif(store_zip_code, ''), 'Unknown') as store_zip_code,
        coalesce(nullif(county_fips_code, ''), 'Unknown') as county_fips_code,
        coalesce(nullif(county_name, ''), 'Unknown') as county_name
    from cleaned
)

select * from null_handled
