# raw_iowa_data_hub.liquor_sales_2023

Profiled 2026-11-07, data as of 2026-11-07 00:03 +07. 2,639,557 rows, ordered
2023-01-02 – 2023-12-30. No row repeats another. One row is one invoice line, as in 2026.

Same as [2024](liquor_sales_2024.md), and through it [2025](liquor_sales_2025.md) and
[2026](liquor_sales_2026.md), except where listed below. Same method and checks. The 5% sample
has 132,432 rows.

## Columns

Only the columns that differ from 2024.

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `ordered_on` | text → date | | 2023-01-02 – 2023-12-30 | 21 Sundays (34,251 rows), 10 Saturdays (57,776 rows) |
| `store_no` | text | | | 2,110 stores; 4-digit up to 9911, 6-digit up to 010319 |
| `store_name` | text | `WILDCAT DISTILLING / WEBSTER CITY (ET)` | | 2,148 names (2026 #5) |
| `store_address` … `county_name` | text | | | NULL on 1,177 lines of 9 stores (2026 #5) |
| `category_code` | text | `1082000` | | 48 codes: the 4 group codes all year (2024 #1) |
| `vendor_number`, `vendor_name` | text | | | 250 vendors, 251 names: 785 renamed (2025 #6) |
| `item_no` | text | | | 5,231 items; no orphans vs `liquor_products` |
| `pack` | text → int | | 1 – 60 | 33 items change pack or volume (2026 #6) |
| `sales_bottles` | text → int | | -648 – 13,200 | |
| `sales_dollars` | text → numeric | | -5,130 – 260,832 | |
| `sales_liters` | text → numeric | | -648 – 13,200 | |
| `sales_gallons` | text → numeric | | -171.18 – 3,487.07 | |

- Top lines: Hy-Vee store 2633's Tito's orders, up to 13,200 bottles. The most negative line
  is a return of 648 `TEN HIGH` by the same store.
- `sales_bottles` bins (sample): `<0` 172, 1–12 114,354, 13–48 14,912, 49–120 1,976,
  121–600 958, `>600` 60.

## Issues

No issue of its own. 2024's issues hold, with these counts:

| # | Column | 2023 | Status |
|---|---|---|---|
| 2024 #1 | `category_code` | The 4 group codes are used all year: 1032000 on 65 lines, 1081000 on 60, 1082000 on 173, 1092000 on 62 | open |
| 2025 #2 | `bottle_volume_ml` | as 2024 | open |
| 2025 #3 | cost, retail | NULL all year | open |
| 2025 #4 | `invoice_id` | Invoice + line, unique on all 2,639,557 lines | open |
| 2025 #5 | `category_name` | The old plural names all year | open |
| 2025 #6 | `vendor_name` | 785 `MAISON FERRAND USA` → `MAISON FERRAND USA / COGNAC FERRAND USA INC` on 2023-02-01 | open |
| 2026 #4 | category | 181 extra (`item_no`, `category_code`) pairs, including 2024 #1 | open |
| 2026 #5 | store columns | Location NULL on 1,177 lines of 9 stores, all with the location on other lines, e.g. 010183's first 696 lines on 2023-03-29 – 30. Zip `57222` on 281 lines. Typos fixed during the year: 010094 address `33501` → `3501 WEST BROADWAY`, 010154 city `FORT DODGE` → `WEBSTER CITY` in the name | open |
| 2026 #6 | `im_desc`, `pack` | 5,368 (`item_no`, `im_desc`) pairs for 5,231 items. 33 items change pack or volume. 23 `99 …` mini items go from pack 10 or 12 to pack 1 on 2023-05-01 | open |
| 2026 #7 | returns | 3,681 `RINV-` lines, 6 positive; 3 `INV-` lines negative | open |
| 2026 #8 | `store_no` | as 2026 | open |
| 2026 #9 | text | Double spaces (sample): `vendor_name` 23,400, `store_address` 6,939, `store_name` 1,863, `im_desc` 139 | open |

<details><summary>Query</summary>

The checks are the 2026 and 2025 queries with the year swapped. Pack changes:

```sql
with s as (select item_no, im_desc, pack, bottle_volume_ml, count(*) as n,
                  min(ordered_on) as first_on, max(ordered_on) as last_on
           from raw_iowa_data_hub.liquor_sales_2023 group by 1, 2, 3, 4)
select * from s where item_no in (select item_no from s group by 1 having count(*) > 1)
order by item_no, first_on;
```
</details>
