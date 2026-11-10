-- One row per order line: drops the export's whole-row repeats (README Q9). Not in staging:
-- collapsing rows changes the grain, and it needs a sort of every line. The store model
-- reads staging directly, since repeats cannot change a store's latest name or location.
with

order_line as (
    select * from {{ ref('stg_iowa_data_hub__liquor_order_line') }}
),

-- order_line_key is a hash of the whole raw row (Q8), so repeats share it. order_year leads
-- the distinct on, so a filter on it still reaches staging and skips the other years' tables.
-- shortcut: two different lines with the same 64-bit key would lose one here, odds about 1
-- in 25,000 over ~38M lines; dedupe on more columns if a line count ever falls short.
deduplicated as (
    select distinct on (order_year, order_line_key) *
    from order_line
    order by order_year, order_line_key
)

select * from deduplicated
