# Liquor order

Sources: [liquor_sales_2026](../../profiling/iowa_data_hub/liquor_sales_2026.md), [liquor_sales_2025](../../profiling/iowa_data_hub/liquor_sales_2025.md),
[products](../../profiling/iowa_data_hub/liquor_products.md)

Scope: 2025–2026. Later years (`liquor_sales_2012` … `liquor_sales_2024`) must fit the same design.

## 1. Business process
Licensed Iowa stores order liquor from the state. The state (ABD) is the wholesaler, so
each sales row is one line of a store's order. Stores return product on the same kind of
invoice (`RINV-`). Why: the rows are wholesale orders at the state retail price
(`sales_dollars` is what the store pays), not sales to shoppers, so "Liquor order" names the
activity better than "liquor sales".

## 2. Grain
One row per invoice line: one item on one store's order from the state, as ABD bills it.
Returns are invoice lines too (`RINV-`, negative quantities) and sit in the same fact.
Why: the line is the atomic event, the finest grain the data has. Every coarser grain
(invoice, store × item × day) sums up from it. Issues that bear on the grain:
[2026 #1](../../profiling/iowa_data_hub/liquor_sales_2026.md#1-invoice_id-is-the-invoice-not-the-line)
(no natural line key from 2025-09-01; an invoice can repeat an identical line),
[2025 #1](../../profiling/iowa_data_hub/liquor_sales_2025.md#1-the-export-repeats-a-slice-of-lines)
(the export repeats a slice of 2025) and
[2026 #7](../../profiling/iowa_data_hub/liquor_sales_2026.md#7-returns-are-rinv--lines-with-negative-quantities)
(returns).

## 3. Dimensions
| Dimension | One value per row because | Conformed with |
|---|---|---|
| Date | the line has one order date (`ordered_on`) | Date (bus matrix column; first real Date dimension) |
| Store | the line has one ordering store; location (city, zip, county) is a store attribute ([2026 #5](../../profiling/iowa_data_hub/liquor_sales_2026.md#5-store-attributes-change-over-time-some-locations-missing)) | — |
| Product | the line has one item, never missing | — |
| Vendor | the line has one vendor, the item's vendor at the time of the order; 66 items changed vendor in 2026 | — |
| Category | the line has one category, the item's category at the time of the order ([2026 #4](../../profiling/iowa_data_hub/liquor_sales_2026.md#4-an-items-category-changes-over-time-26-lines-have-none)); on Product it would be multivalued ([products #1](../../profiling/iowa_data_hub/liquor_products.md#1-item_no-is-not-unique)) | — |
| Invoice (degenerate, on the fact) | the line belongs to one invoice, with one type: order (`INV-`) or return (`RINV-`) ([2026 #7](../../profiling/iowa_data_hub/liquor_sales_2026.md#7-returns-are-rinv--lines-with-negative-quantities)) | — |

Why Vendor and Category stand alone, not inside Product: both change per item over time,
the line records the value that applied at the order, and analysts slice by each on its own.

## 4. Facts
| Fact | Additivity | Note |
|---|---|---|
| Bottles ordered | additive | negative on returns ([2026 #7](../../profiling/iowa_data_hub/liquor_sales_2026.md#7-returns-are-rinv--lines-with-negative-quantities)) |
| Order amount | additive | what the store pays the state; [2026 #2](../../profiling/iowa_data_hub/liquor_sales_2026.md#2-money-and-volume-are-whole-numbers-in-jan-2026), [2026 #3](../../profiling/iowa_data_hub/liquor_sales_2026.md#3-sales_dollars--bottles--retail-on-some-lines) |
| Volume in liters | additive | [2026 #2](../../profiling/iowa_data_hub/liquor_sales_2026.md#2-money-and-volume-are-whole-numbers-in-jan-2026) |
| State cost amount | additive | derived: bottles × state bottle cost; [2025 #3](../../profiling/iowa_data_hub/liquor_sales_2025.md#3-cost-and-retail-are-null-before-2025-07-01) |
| State bottle cost | non-additive | unit price as billed on the line; [2025 #3](../../profiling/iowa_data_hub/liquor_sales_2025.md#3-cost-and-retail-are-null-before-2025-07-01) |
| State bottle retail | non-additive | unit price as billed on the line; [2025 #3](../../profiling/iowa_data_hub/liquor_sales_2025.md#3-cost-and-retail-are-null-before-2025-07-01) |

Gallons (`sales_gallons`) is dropped: a measure nobody needs. Pack and bottle volume describe
the product as sold ([2026 #6](../../profiling/iowa_data_hub/liquor_sales_2026.md#6-item-description-and-pack-change-over-time)):
they belong to Product, not the fact.

## Bubble chart
```mermaid
flowchart LR
    date[Date] --- f["<b>Liquor order</b><br/>Grain: 1 row per invoice line<br/>(returns as negative lines)"]
    store[Store] --- f
    f --- product[Product]
    f --- vendor[Vendor]
    f --- category[Category]
```

## Open questions
- Publisher questions that bear on this design, open in the profiling record:
  [README Q8](../../profiling/iowa_data_hub/_README.md#questions-for-the-human) (line key),
  Q9 (doubled late 2025), Q10 (rounded money), Q11 (order amount vs bottles × retail).
