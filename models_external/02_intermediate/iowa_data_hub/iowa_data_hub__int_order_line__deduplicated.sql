-- One row per order line: drops the export's whole-row repeats (README Q9). Not in staging:
-- collapsing rows changes the grain, and it needs a sort of every line. The store model
-- reads staging directly, since repeats cannot change a store's latest name or location.
with

order_line as (
    select * from {{ ref('stg_iowa_data_hub__liquor_order_line') }}
),

-- order_line_no stands for the whole row: invoice_id up to 2025-08-29, unique on distinct
-- rows (Q8), then an md5 of the row. order_year leads the distinct on, so a filter on it
-- still reaches staging and skips the other years' tables.
deduplicated as (
    select distinct on (order_year, order_line_no) *
    from order_line
    order by order_year, order_line_no
)

select * from deduplicated
