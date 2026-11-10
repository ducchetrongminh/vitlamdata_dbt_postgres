-- One row per product: every item in the catalog or on a sales line (README Q1), with one
-- category (type 1). Catalog values win where both have one: the catalog is today's list.
-- The category, per README Q2, Q16, Q17, Q19, Q21:
-- - an item sold takes the category code of its latest line
--   (iowa_data_hub__int_product__latest_picked). A retired code is mapped by seed
--   iowa_data_hub__legacy_category_map, in the window of the line's date;
-- - an item never sold, or last sold before 2016-08-29 but still in the catalog, takes its
--   catalog category (Q2, Q19): the catalog has names only, so the code is the one whose
--   latest name matches;
-- - the code's latest name (iowa_data_hub__int_category__latest_named) is category_name; the
--   name on the item's latest line is historic_category_name (type 3, Q21).
with

catalog_product as (
    select * from {{ ref('stg_iowa_data_hub__liquor_product') }}
),

sold_product as (
    select * from {{ ref('iowa_data_hub__int_product__latest_picked') }}
),

category as (
    select * from {{ ref('iowa_data_hub__int_category__latest_named') }}
),

category_map as (
    select * from {{ ref('iowa_data_hub__legacy_category_map') }}
),

ranked as (
    select
        *,
        row_number() over (
            partition by product_code
            -- README Q2: the two tag categories only when the item has nothing else.
            -- shortcut: 8 items have two real categories, so the first by name wins; only
            -- items not sold since 2016-08-29 use it.
            order by
                category_name in ('Temporary & Specialty Packages', 'Iowa Spirits Manufacturers'),
                category_name
        ) as category_rank
    from catalog_product
),

catalog_picked as (
    select * from ranked
    where category_rank = 1
),

-- A name can belong to several codes (a retired code and its replacement), so take the code
-- used last
category_by_name as (
    select distinct on (category_name)
        category_name,
        category_code
    from category
    order by category_name, last_order_year desc, category_code desc
),

sold_mapped as (
    select
        sold_product.*,
        coalesce(category_map.category_code, sold_product.category_code) as mapped_category_code
    from sold_product
    left join category_map
        on sold_product.category_code = category_map.legacy_category_code
        and (category_map.ordered_from is null
            or sold_product.category_ordered_on >= category_map.ordered_from)
        and (category_map.ordered_before is null
            or sold_product.category_ordered_on < category_map.ordered_before)
),

joined as (
    select
        -- Keys
        coalesce(catalog_picked.product_code, sold_mapped.product_code) as product_code,
        -- Name, desc
        coalesce(catalog_picked.product_name, sold_mapped.product_name) as product_name,
        -- Category
        case
            when catalog_picked.product_code is not null
                and (sold_mapped.product_code is null
                    or sold_mapped.category_ordered_on < '2016-08-29')
                then category_by_name.category_code
            else sold_mapped.mapped_category_code
        end as category_code,
        upper(catalog_picked.category_name) as catalog_category_name,
        sold_mapped.category_name as historic_category_name,
        -- Attributes
        coalesce(catalog_picked.pack, sold_mapped.pack) as pack,
        catalog_picked.inner_pack,
        coalesce(catalog_picked.bottle_volume_ml, sold_mapped.bottle_volume_ml) as bottle_volume_ml,
        catalog_picked.proof,
        catalog_picked.age_years,
        catalog_picked.upc,
        catalog_picked.listed_date,
        catalog_picked.state_bottle_cost_unit_price,
        catalog_picked.state_bottle_retail_unit_price
    from catalog_picked
    full outer join sold_mapped
        on catalog_picked.product_code = sold_mapped.product_code
    left join category_by_name
        on category_by_name.category_name = upper(catalog_picked.category_name)
),

category_named as (
    select
        -- Keys
        joined.product_code,
        -- Name, desc
        joined.product_name,
        -- Attributes
        joined.category_code,
        coalesce(category.category_name, joined.catalog_category_name) as category_name,
        coalesce(
            joined.historic_category_name,
            category.category_name,
            joined.catalog_category_name
        ) as historic_category_name,
        joined.pack,
        joined.inner_pack,
        joined.bottle_volume_ml,
        joined.proof,
        joined.age_years,
        joined.upc,
        joined.listed_date,
        joined.state_bottle_cost_unit_price,
        joined.state_bottle_retail_unit_price
    from joined
    left join category
        on joined.category_code = category.category_code
),

null_handled as (
    select
        -- Keys
        product_code,
        -- Name, desc
        coalesce(nullif(product_name, ''), 'Unknown') as product_name,
        -- Attributes
        coalesce(category_code, 'Unknown') as category_code,
        coalesce(nullif(category_name, ''), 'Unknown') as category_name,
        coalesce(nullif(historic_category_name, ''), 'Unknown') as historic_category_name,
        pack,
        inner_pack,
        bottle_volume_ml,
        proof,
        age_years,
        coalesce(upc, 'Unknown') as upc,
        listed_date,
        state_bottle_cost_unit_price,
        state_bottle_retail_unit_price
    from category_named
),

unknown_product as (
    select
        -- Keys
        'UNKNOWN' as product_code,
        -- Name, desc
        'Unknown' as product_name,
        -- Attributes
        'Unknown' as category_code,
        'Unknown' as category_name,
        'Unknown' as historic_category_name,
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
    select * from null_handled
    union all
    select * from unknown_product
)

select * from inserted_unknown
