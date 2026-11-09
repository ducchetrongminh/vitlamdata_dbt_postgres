# raw_iowa_data_hub.liquor_sales_2015

Profiled 2026-11-07, data as of 2026-11-07 00:03 +07. 2,184,483 rows, ordered
2015-01-05 – 2015-12-31. No row repeats another. One row is one invoice line, as in 2026.

Same as [2016](liquor_sales_2016.md) before its 2016-08-29 change, and through it the later
years, except where listed below. The whole year is on the old system (2016 #1). Same method
and checks. The 5% sample has 107,196 rows.

## Columns

Only the columns that differ from 2016.

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `invoice_id` | text | `S24426100046`, `S444400001` | | `S` + 11 digits; 80 lines with 9 digits (#1). Unique |
| `ordered_on` | text → date | | 2015-01-05 – 2015-12-31 | no Sunday; 2 Saturdays (21,551 rows); Fridays on 21 days only (48,914 rows) |
| `store_no` | text | | | 1,375 stores, 4 digits (2106–9023) |
| `store_name` | text | `QUIK SHOP FOODS / FOUR M IN` | | 1,376 names: almost no renames within the year |
| `store_address` … `store_zip_code` | text | | | never NULL. `712-2` on 1,725 lines of store 4307 (2016 #3) |
| `county_fips_code`, `county_name` | text | | | NULL on 1,119 lines, all store 4247 (2016 #4) |
| `category_code`, `category_name` | text | `1031080 VODKA 80 PROOF`, `1501100 HIGH PROOF BEER - AMERICAN` | | 84 codes, old taxonomy all year (2016 #1); a beer category (#2). NULL code on 773 lines |
| `vendor_number`, `vendor_name` | text | `10` | | 147 vendors, one name each; 2 digits on 515,339 lines (2016 #1); no NULL |
| `item_no` | text | | | 3,595 items; 1,735 not in `liquor_products` (2022 #2) |
| `bottle_volume_ml` | text → int | | 0 – 180,000 | 0 on 2 lines (#3) |
| `sales_bottles` | text → int | | 1 – 3,960 | no 0 |
| `sales_dollars` | text → numeric | | 1.34 – 106,326 | no $0 line (2018 #2 does not occur) |
| `sales_liters` | text → numeric | | 0 – 3,960 | 0 on the 2 lines of #3 |

- Top lines: Hy-Vee 2633 ordered 3,960 bottles of Jack Daniel's for $106,326 on 2015-03-09.
- `sales_bottles` bins (sample): 1–12 96,329, 13–48 9,379, 49–120 1,078, 121–600 388,
  `>600` 22.
- Text (sample): no non-ASCII; 28 category names with double spaces.

## Issues

| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `invoice_id` | One invoice of store 3573 on 2015-01-07 has 9 digits (`S444400001` – `S444400083`), not 11 | accept: still unique | open |
| 2 | `category_code` | `1501100 HIGH PROOF BEER - AMERICAN` on 6 lines of `SAM ADAMS UTOPIAS HA`; `1089290` with no name on 1 line | accept | open |
| 3 | `bottle_volume_ml` | 0 on 2 lines of 941063 `BURNETT'S PINK LEMONADE VODKA MINI`, so liters are 0 | clean in staging: take the volume from the item's other lines (a mini: 50 ml is a guess) | open |
| 2016 #1 | invoice, category, vendor | Old system all year | as 2016 #1 | decided |
| 2016 #3 | `store_zip_code` | `712-2` on 1,725 lines | as 2016 #3 | open |
| 2016 #4 | county | NULL with an address on 1,119 lines, all store 4247 `FAREWAY STORES #879 / BELMOND` | as 2016 #4 | open |
| 2022 #2 | `item_no` | 1,735 items, 156,750 lines (7.2%), not in the catalog | as 2022 #2 | open |
| 2025 #2 | `bottle_volume_ml` | Pack total for the 2025 #2 items, e.g. 48102 at 1,200 | as 2025 #2 | open |
| 2025 #3 | cost, retail | NULL all year | as 2025 #3 | open |
| 2026 #4 | category | NULL code on 773 lines of 20 items; NULL name with a code on 689 more. Mostly gift packs, e.g. 3657 `HERRADURA GOLD REPOSADO 6PAK` | as 2026 #4 | open |
| 2026 #9 | text | Double spaces (sample): `store_address` 9,898, `store_name` 2,384, `vendor_name` 826 | as 2026 #9 | open |

No store location is missing (2017 #2 does not occur), and no vendor is renamed.

<details><summary>Query</summary>

The checks are the later years' queries with the year swapped. #1–#3:

```sql
select invoice_id, ordered_on, store_no, item_no, im_desc
from raw_iowa_data_hub.liquor_sales_2015 where invoice_id ~ '^S\d{9}$';

select invoice_id, ordered_on, item_no, im_desc, category_code, category_name, bottle_volume_ml
from raw_iowa_data_hub.liquor_sales_2015
where category_code in ('1501100', '1089290') or bottle_volume_ml::int = 0;
```
</details>
