# raw_iowa_data_hub.liquor_sales_2014

Profiled 2026-11-07, data as of 2026-11-07 00:03 +07. 2,097,796 rows, ordered
2014-01-02 – 2014-12-31. No row repeats another. One row is one invoice line, as in 2026.

Same as [2015](liquor_sales_2015.md), and through it the later years, except where listed
below. The whole year is on the old system (2016 #1). Same method and checks. The 5% sample
has 103,646 rows.

## Columns

Only the columns that differ from 2015.

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `invoice_id` | text | `S19816600002` | | `S` + 11 digits on every line. Unique |
| `ordered_on` | text → date | | 2014-01-02 – 2014-12-31 | no Sunday; 3 Saturdays (27,370 rows); Fridays on 16 days only |
| `store_no`, `store_name` | text | | | 1,319 stores, one name each all year |
| `county_fips_code`, `county_name` | text | | | NULL on 1,054 lines, all store 4247 (2016 #4) |
| `category_code`, `category_name` | text | `101220` | | 79 codes; one with 6 digits (#1). NULL code on 480 lines |
| `vendor_number`, `vendor_name` | text | | | 149 vendors, one name each; 2 digits on 510,354 lines (2016 #1) |
| `item_no`, `im_desc`, `pack`, `bottle_volume_ml` | text | | | 3,592 items, one description, pack and volume each all year |
| `bottle_volume_ml` | text → int | | 0 – 140,000 | 0 on 7 lines (2015 #3) |
| `sales_bottles` | text → int | | 1 – 3,456 | |
| `sales_dollars` | text → numeric | | 1.46 – 94,590.72 | |
| `sales_liters` | text → numeric | | 0 – 5,250 | |

- Top lines: Hy-Vee 2633 ordered 3,456 bottles of Crown Royal for $94,590.72 on 2014-06-27.
- `sales_bottles` bins (sample): 1–12 93,256, 13–48 8,948, 49–120 1,051, 121–600 371,
  `>600` 20.

## Issues

| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `category_code` | `101220` (6 digits, no name) on 2 lines of 901369 `CRAIGELLACHIE`, a Scotch | clean in staging: guess `1012200` (a digit dropped); ask | open |
| 2015 #3 | `bottle_volume_ml` | 0 on 7 lines of 3 items: 934962 `THREE OLIVES ORANGE VODKA` (5), 941063 `BURNETT'S PINK LEMONADE VODKA MINI` (1), 964590 `CANADIAN CLUB DOCK 57 MINI DNO` (1) | as 2015 #3 | open |
| 2016 #1 | invoice, category, vendor | Old system all year | as 2016 #1 | open |
| 2016 #3 | `store_zip_code` | `712-2` on 1,780 lines | as 2016 #3 | open |
| 2016 #4 | county | NULL with an address on 1,054 lines, all store 4247 | as 2016 #4 | open |
| 2022 #2 | `item_no` | 1,913 items, 196,372 lines (9.4%), not in the catalog, e.g. 75211 `KINKY LIQUEUR` (5,476), 73050 `RUMCHATA` (2,490) | as 2022 #2 | open |
| 2025 #2 | `bottle_volume_ml` | Pack total for the 2025 #2 items, e.g. 48102 at 1,200 | as 2025 #2 | open |
| 2025 #3 | cost, retail | NULL all year | as 2025 #3 | open |
| 2026 #4 | category | NULL code on 480 lines of 11 items; NULL name with a code on 577 more. Mostly gift packs, e.g. 3657 `HERRADURA GOLD REPOSADO 6PAK` | as 2026 #4 | open |
| 2026 #9 | text | Double spaces (sample): `store_address` 8,601, `store_name` 811, `vendor_name` 632 | as 2026 #9 | open |

No item, store or vendor attribute changes within the year (2026 #5 and #6 do not occur).

<details><summary>Query</summary>

```sql
select invoice_id, ordered_on, item_no, im_desc, category_code, category_name, bottle_volume_ml
from raw_iowa_data_hub.liquor_sales_2014
where category_code !~ '^\d{7}$' or bottle_volume_ml::int = 0;
```
</details>
