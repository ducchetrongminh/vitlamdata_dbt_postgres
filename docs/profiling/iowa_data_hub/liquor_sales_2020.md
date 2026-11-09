# raw_iowa_data_hub.liquor_sales_2020

Profiled 2026-11-07, data as of 2026-11-07 00:03 +07. 3,147,745 rows, ordered
2020-01-02 – 2020-12-31. The export repeats 533,380 of them (2025 #1), so 2,614,365 rows are
distinct. One row is one invoice line, as in 2026.

Same as [2021](liquor_sales_2021.md), and through it the later years, except where listed
below. Same method and checks. The 5% sample has 158,430 rows. Counts are on all rows,
repeats included, unless stated.

## Columns

Only the columns that differ from 2021.

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `ordered_on` | text → date | | 2020-01-02 – 2020-12-31 | 5 Sundays (216 rows), 2 Saturdays (25,350 rows) |
| `store_no` | text | | | 1,878 stores, 4 digits (2106–9946) |
| `store_name` | text | `HY-VEE C-STRORE - DOUGLAS` | | 1,903 names (2026 #5) |
| `category_code`, `category_name` | text | `1700000`, `1011800` | | 57 codes; NULL on 682 lines (2026 #4) |
| `vendor_number`, `vendor_name` | text | | | 202 vendors, 211 names: 7 renamed (2025 #6). No NULL |
| `item_no` | text | `258` | | 4,176 items; 400 not in `liquor_products` (2022 #2) |
| `pack` | text → int | | 1 – 60 | 44 items change pack or volume (2026 #6) |
| `bottle_volume_ml` | text → int | | 20 – 6,000 | 6,000 is item 258 `RUMCHATA GOCHATAS`, a pack total (2025 #2) |
| `sales_dollars` | text → numeric | | 1.30 – 250,932 | |

- Top lines: besides Hy-Vee 2633, two Sam's Club stores ordered 7,920 bottles of Tito's in
  Sep 2020.
- `sales_bottles` bins (sample): 1–12 139,091, 13–48 15,924, 49–120 2,225, 121–600 1,142,
  `>600` 48.

## Issues

No issue of its own. The later years' issues hold, with these counts:

| # | Column | 2020 | Status |
|---|---|---|---|
| 2025 #1 | all | The export repeats every line from midway through 2020-10-22 to 2020-12-31: 67,848 extra rows in Oct, 211,643 in Nov, 253,889 in Dec | open |
| 2022 #1 | category, returns, stores | Old system all year: no returns, 4-digit stores only. `1700000 TEMPORARY & SPECIALTY PACKAGES` starts 2020-03-02 (13,276 lines). Codes only here: `1011800 IOWA DISTILLERY WHISKIES` (10 lines, Jan), `1900000 DELISTED / SPECIAL ORDER ITEMS` (1 line) | open |
| 2022 #2 | `item_no` | 400 items, 10,172 lines, not in the catalog, e.g. 18096 `EVAN WILLIAMS 1783` (660), 72916 `CAPTAIN MORGAN WATERMELON SMASH` (593) | open |
| 2025 #2 | `bottle_volume_ml` | Pack total, e.g. 48102 at 1,200, 68039 at 2,400. 100636 `JIM BEAM MINI 12 SEASONS` goes 600 → 50 in Oct 2020 | open |
| 2025 #3 | cost, retail | NULL all year | open |
| 2025 #4 | `invoice_id` | Invoice + line, unique on the 2,614,365 distinct lines | open |
| 2025 #6 | `vendor_name` | 7 renamed, e.g. 469 `TY KU LLC` → `DAVOS BRANDS LLC` on 2020-05-01, a different company under the same number | open |
| 2026 #4 | category | NULL on 682 lines of 45 items, 2020-01-02 – 2020-05-29, e.g. 80024 `BLUE CHAIR BAY BANANA RUM CREAM` (242 lines) | open |
| 2026 #5 | store columns | Location NULL on 135 lines of 3 stores, all with the location on other lines. Zip `57222` on 438 lines. Stores 4378 and 4411 carry each other's names on 2020-09-16. Typos: `C-STRORE`, `FOOD LAND` | decided |
| 2026 #6 | `im_desc`, `pack` | 4,296 (`item_no`, `im_desc`) pairs for 4,176 items. 44 items change pack or volume, e.g. 100440 `SKYY VODKA 1.75L …` at 175 ml in Apr, 1,750 after | open |
| 2026 #9 | text | Double spaces (sample): `vendor_name` 14,966, `store_address` 13,346, `store_name` 3,566, `im_desc` 106 | decided |

<details><summary>Query</summary>

The checks are the 2026, 2025 and 2022 queries with the year swapped. NULL category:

```sql
select item_no, im_desc, count(*), min(ordered_on), max(ordered_on)
from raw_iowa_data_hub.liquor_sales_2020 where category_code is null
group by 1, 2 order by 3 desc;
```
</details>
