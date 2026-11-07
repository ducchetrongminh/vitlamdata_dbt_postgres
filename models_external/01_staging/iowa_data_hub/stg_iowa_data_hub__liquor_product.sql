-- Cleanup per docs/profiling/iowa_data_hub/liquor_products.md (issues #n) and _README.md (Qn).
with

source as (
    select * from {{ source('iowa_data_hub', 'liquor_products') }}
),

renamed as (
    select
        -- Keys
        item_no as product_code,
        category_name,
        -- Name, desc
        im_desc as product_name,
        -- Attributes
        pack,
        inner_pack,
        bottle_volume_ml,
        proof,
        age,
        upc,
        list_on as listed_date,
        state_bottle_cost as state_bottle_cost_unit_price,
        state_bottle_retail as state_bottle_retail_unit_price
    from source
),

casted as (
    select
        -- Keys
        cast(product_code as text) as product_code,
        cast(category_name as text) as category_name,
        -- Name, desc
        cast(product_name as text) as product_name,
        -- Attributes
        cast(pack as integer) as pack,
        cast(inner_pack as integer) as inner_pack,
        cast(bottle_volume_ml as integer) as bottle_volume_ml,
        cast(proof as numeric) as proof,
        cast(age as integer) as age,
        cast(upc as text) as upc,
        cast(listed_date as date) as listed_date,
        cast(state_bottle_cost_unit_price as numeric) as state_bottle_cost_unit_price,
        cast(state_bottle_retail_unit_price as numeric) as state_bottle_retail_unit_price,
        -- age stated in the description, e.g. 'Laphroaig 10YR', 'Juan in a Million 116 month'
        cast((regexp_match(product_name, '(\d+)\s*-?\s*(?:yr|yrs|year|years|yo)\M', 'i'))[1] as numeric)
            as stated_years,
        cast((regexp_match(product_name, '(\d+)\s*-?\s*months?\M', 'i'))[1] as numeric)
            as stated_months
    from renamed
),

cleaned as (
    select
        -- Keys
        product_code,
        case category_name                                  -- #2: rare plural/singular twins
            when 'American Cordials & Liqueurs' then 'American Cordials & Liqueur'
            when 'Imported Cordials & Liqueurs' then 'Imported Cordials & Liqueur'
            when 'Imported Vodka' then 'Imported Vodkas'
            else category_name
        end as category_name,
        -- Name, desc
        regexp_replace(trim(product_name), '\s{2,}', ' ', 'g') as product_name,   -- #11
        -- Attributes
        pack,
        inner_pack,
        nullif(bottle_volume_ml, 0) as bottle_volume_ml,    -- #6: 0 on non-retail items
        nullif(proof, 0) as proof,                          -- #6
        -- #5, Q3: age in years. The catalog value holds from 1 to 35. At 0 (none) or 36+
        -- (mostly months), a stated age in the description wins; else 36+ is months,
        -- except 915385 (years), and 0 is no age. Values 1-35 ignore the description,
        -- which can mislead ('Yellowstone Hand Picked 250 yr Anniversary'). A stated age
        -- over 80 is an anniversary or a year ('Cutty Sark Original 100YR', 'Don Julio
        -- 1942 Year Of The Horse'), not an age: the oldest real one in the catalog is 60.
        case
            when age between 1 and 35 then age
            when stated_years between 1 and 80 then stated_years
            when stated_months between 1 and 960 then round(stated_months / 12, 1)
            when age >= 36 and product_code <> '915385' then round(age / 12.0, 1)
            when age >= 36 then age
        end as age_years,
        case when upc ~ '^0+$' then null else upc end as upc,   -- #9: all-zero placeholder
        listed_date,
        state_bottle_cost_unit_price,
        state_bottle_retail_unit_price
    from casted
),

null_handled as (
    select
        -- Keys
        product_code,
        coalesce(nullif(category_name, ''), 'Unknown') as category_name,
        -- Name, desc
        coalesce(nullif(product_name, ''), 'Unknown') as product_name,
        -- Attributes
        pack,
        inner_pack,
        bottle_volume_ml,
        proof,
        age_years,
        coalesce(nullif(upc, ''), 'Unknown') as upc,
        listed_date,
        state_bottle_cost_unit_price,
        state_bottle_retail_unit_price
    from cleaned
)

select * from null_handled
