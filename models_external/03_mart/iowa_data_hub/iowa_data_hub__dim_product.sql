with

product as (
    select * from {{ ref('iowa_data_hub__int_product__category_picked') }}
),

final as (
    select
        -- Keys
        {{ generate_bigint_surrogate_key(['product_code']) }} as product_key,
        product_code,
        -- Name, desc
        product_name,
        -- Attributes
        category_code,
        category_name,
        historic_category_name,
        pack,
        inner_pack,
        bottle_volume_ml,
        proof,
        age_years,
        upc,
        listed_date,
        state_bottle_cost_unit_price,
        state_bottle_retail_unit_price
    from product
)

select * from final
