-- The cleanup is in base_iowa_data_hub__liquor_order_line; staging drops the repeats.
with

base as (
    select * from {{ ref('base_iowa_data_hub__liquor_order_line') }}
),

-- Q9: drop whole-row repeats. order_line_id stands for the whole row: invoice_id up to
-- 2025-08-29, unique on distinct rows (Q8), then an md5 of the row. order_year leads the
-- distinct on, so a filter on it still reaches the base model and skips the other years.
filtered as (
    select distinct on (order_year, order_line_id) *
    from base
    order by order_year, order_line_id
)

select * from filtered
