-- One row per product: the catalog lists some items under 2-3 categories
-- (docs/profiling/iowa_data_hub/liquor_products.md #1), and Product holds one (type 1).
with

catalog_product as (
    select * from {{ ref('stg_iowa_data_hub__liquor_product') }}
),

ranked as (
    select
        *,
        row_number() over (
            partition by product_code
            -- README Q2: the two tag categories only when the item has nothing else.
            -- shortcut: 8 items have two real categories, so the first by name wins;
            -- take the latest sales category (Q2) once sales lines are staged.
            order by
                category_name in ('Temporary & Specialty Packages', 'Iowa Spirits Manufacturers'),
                category_name
        ) as category_rank
    from catalog_product
),

category_picked as (
    select
        -- Keys
        product_code,
        -- Name, desc
        product_name,
        -- Attributes
        category_name,
        pack,
        inner_pack,
        bottle_volume_ml,
        proof,
        age_years,
        upc,
        listed_date,
        state_bottle_cost_unit_price,
        state_bottle_retail_unit_price
    from ranked
    where category_rank = 1
),

unknown_product as (
    select
        -- Keys
        'UNKNOWN' as product_code,
        -- Name, desc
        'Unknown' as product_name,
        -- Attributes
        'Unknown' as category_name,
        null::integer as pack,
        null::integer as inner_pack,
        null::integer as bottle_volume_ml,
        null::numeric as proof,
        null::numeric as age_years,
        'Unknown' as upc,
        null::date as listed_date,
        null::numeric as state_bottle_cost_unit_price,
        null::numeric as state_bottle_retail_unit_price
),

inserted_unknown as (
    select * from category_picked
    union all
    select * from unknown_product
)

select * from inserted_unknown
