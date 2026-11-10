# raw_iowa_data_hub.liquor_sales_2021

Profiled 2026-11-07, data as of 2026-11-07 00:03 +07. 3,098,706 rows, ordered
2021-01-04 – 2021-12-31. The export repeats 475,994 of them (2025 #1), so 2,622,712 rows are
distinct. One row is one invoice line, as in 2026.

Same as [2022](liquor_sales_2022.md) before its 2022-07-18 change, and through it the later
years, except where listed below. Same method and checks. The 5% sample has 156,336 rows.
Counts are on all rows, repeats included, unless stated.

## Columns

Only the columns that differ from 2022.

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `invoice_id` | text | `INV-35909600152` | | `INV-` only: no returns (2022 #1) |
| `ordered_on` | text → date | | 2021-01-04 – 2021-12-31 | 34 Sundays (3,355 rows), 6 Saturdays (25,247 rows) |
| `store_no` | text | `2190`, `4169` | | 1,948 stores, all 4 digits (2106–9049) |
| `store_name` | text | `HY-VEE C-STORE / FAIRFEILD` | | 1,970 names (2026 #5) |
| `category_code` | text | `1071100`, `1070100` | | 57 codes, the pre-2022-07-18 set (2022 #1), plus 2 used only in 2021 |
| `vendor_number`, `vendor_name` | text | | | 220 vendors, 225 names. NULL on 4 lines (#1) |
| `item_no` | text | | | 4,472 items; 14 not in `liquor_products` (2022 #2) |
| `sales_bottles` | text → int | | 1 – 13,200 | no negative line |
| `sales_dollars` | text → numeric | | 1.34 – 250,932 | |
| `sales_liters` | text → numeric | | 0.02 – 13,200 | |
| `sales_gallons` | text → numeric | | 0 – 3,487.07 | |

- `sales_bottles` bins (sample): 1–12 136,325, 13–48 16,482, 49–120 2,389, 121–600 1,089,
  `>600` 51.

## Issues

| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `vendor_number`, `vendor_name` | NULL on 4 lines of 3 special-order items | clean in staging: take the vendor from the item's other lines or the catalog | open |
| 2025 #1 | all | The export repeats every line from midway through 2021-11-01 to 2021-12-31: 220,475 extra rows in Nov, 255,519 in Dec | as 2025 #1 | open |
| 2022 #1 | category, returns, stores | All year on the old system: old category codes, no returns, no 6-digit store numbers. Two codes appear only here: `1011000 AMERICAN WHISKIES` (1 line), `1070100 TEMPORARY & SPECIALTY PACKAGES` (5 lines, Jan) | as 2022 #1 | open |
| 2022 #2 | `item_no` | 14 items, 1,949 lines, not in the catalog. Most are 21540 `STAGG JR.` (1,663 lines) and 18096 `EVAN WILLIAMS 1783` (210) | as 2022 #2 | open |
| 2025 #2 | `bottle_volume_ml` | Pack total, as later years, e.g. 48102 at 1,200, 68039 at 2,400 | as 2025 #2 | open |
| 2025 #3 | cost, retail | NULL all year | as 2025 #3 | open |
| 2025 #4 | `invoice_id` | Invoice + line, unique on the 2,622,712 distinct lines | as 2025 #4 | open |
| 2025 #6 | `vendor_name` | 4 renamed: 322, 338, 479, 886 | as 2025 #6 | open |
| 2026 #5 | store columns | Location NULL on 196 lines of 3 stores, all with the location on other lines. Zip `57222` on 421 lines. Typos: `FAIRFEILD`, `CEDAR FALL`. 2658 moves address in Feb | as 2026 #5 | decided |
| 2026 #6 | `im_desc`, `pack` | 4,776 (`item_no`, `im_desc`) pairs for 4,472 items. Many changes add a prefix: `SOOH ` (44), `CM `, `ND `. 19 items change pack or volume | as 2026 #6 | open |
| 2026 #9 | text | Double spaces (sample): `vendor_name` 21,069, `store_address` 12,057, `store_name` 2,873, `im_desc` 128 | as 2026 #9 | decided |

### 1. Vendor missing on 4 lines

| invoice_id | ordered_on | item_no | im_desc | category_name |
|---|---|---|---|---|
| INV-33740700003 | 2021-01-25 | 915574 | CONNEMARA 12 YEAR | IRISH WHISKIES |
| INV-33728600005 | 2021-01-25 | 988100 | MONTE ALBAN SILVER | 100% AGAVE TEQUILA |
| INV-35139200005 | 2021-03-18 | 965108 | GREY GOOSE VX | IMPORTED VODKAS |
| INV-35973800003 | 2021-04-20 | 915574 | CONNEMARA 12YR | IRISH WHISKIES |

All are special-order item numbers (9xxxxx). Every other column is filled.

<details><summary>Query</summary>

```sql
select invoice_id, ordered_on, item_no, im_desc, vendor_number, vendor_name, category_name
from raw_iowa_data_hub.liquor_sales_2021 where vendor_number is null;
```
</details>
