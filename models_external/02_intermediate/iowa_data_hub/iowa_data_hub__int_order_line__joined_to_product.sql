-- One row per order line, with liters from the product's latest bottle volume (README Q15):
-- the line's own volume flips between a bottle's and a pack's ml for some minis (2018 #1,
-- 2019 #1, 2025 #2), and liters are rounded in Jan 2026 (Q10).
with

order_line as (
    select * from {{ ref('iowa_data_hub__int_order_line__deduplicated') }}
),

product as (
    select * from {{ ref('iowa_data_hub__int_product__category_picked') }}
),

joined as (
    select
        -- Keys
        order_line.order_line_key,
        order_line.invoice_no,
        order_line.store_code,
        order_line.product_code,
        order_line.vendor_code,
        -- Attributes
        order_line.invoice_type,
        -- Dates
        order_line.order_date,
        order_line.order_year,
        -- Measures
        order_line.bottle_qty,
        order_line.bottle_qty * product.bottle_volume_ml / 1000.0 as liter_qty,
        order_line.state_bottle_cost_unit_price,
        order_line.state_bottle_retail_unit_price,
        order_line.order_amt,
        order_line.state_cost_amt
    from order_line
    left join product
        on product.product_code = order_line.product_code
)

select * from joined
