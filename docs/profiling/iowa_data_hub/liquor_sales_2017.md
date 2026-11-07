# raw_iowa_data_hub.liquor_sales_2017

Profiled 2026-11-07, data as of 2026-11-07 00:03 +07. 2,291,276 rows, ordered
2017-01-03 – 2017-12-29. No row repeats another. One row is one invoice line, as in 2026.

Same as [2018](liquor_sales_2018.md), and through it the later years, except where listed
below. Same method and checks. The 5% sample has 112,317 rows.

## Columns

Only the columns that differ from 2018.

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `ordered_on` | text → date | | 2017-01-03 – 2017-12-29 | no Sunday; 1 Saturday (3 rows) |
| `store_no` | text | | | 1,523 stores, 4 digits (2106–9934) |
| `store_name` | text | `HY-VEE WINE AND SPIRITS #2` | | 1,574 names (2026 #5) |
| `store_address` … `county_name` | text | `OTTUWMA` | | NULL on 43,477 lines, 1.9% (#2); all stores in Iowa |
| `category_code`, `category_name` | text | `1701200 HOLIDAY VAP` | | 54 codes; NULL on 3,130 lines (2026 #4) |
| `vendor_number`, `vendor_name` | text | | | 193 vendors, 197 names; no NULL |
| `item_no` | text | `x904631` | | 3,901 items; one with a letter (#1); 1,523 not in `liquor_products` (2022 #2) |
| `bottle_volume_ml` | text → int | | 50 – 31,500 | 31,500 ml = 18 × 1.75 L in one shipper (2025 #2) |
| `sales_bottles` | text → int | | 0 – 6,600 | 2 lines with 0 bottles (2018 #2) |
| `sales_dollars` | text → numeric | | 0 – 114,798.12 | 833 lines with $0 (2018 #2) |
| `sales_liters` | text → numeric | | 0.03 – 7,087.5 | |
| `sales_gallons` | text → numeric | | 0 – 1,872.32 | |

- Top lines: Hy-Vee 2633 ordered 6,600 bottles of Barton vodka on 2017-11-27. The largest
  amount is Crown Royal for Hy-Vee Urbandale, $114,798.12.
- `sales_bottles` bins (sample): 1–12 99,899, 13–48 10,458, 49–120 1,379, 121–600 542,
  `>600` 39.

## Issues

| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `item_no` | `x904631` on 2 lines: a mis-keyed `904631` | clean in staging: strip the `x` | open |
| 2 | store location | NULL on 43,477 lines (1.9%) of 49 stores; 6 stores have no location all year | clean in staging: fill from the same store in other years | open |
| 2018 #2 | `sales_dollars` | 833 lines with bottles but $0, all year (32–111 a month); 2 lines with $ but 0 bottles | as 2018 #2 | open |
| 2019 #1 | `bottle_volume_ml` | No volume changes in 2017. The 2025 #2 items carry the pack total, e.g. 48102 at 1,200. Three `RETAIL READY 3PK SHIPPER` items at 31,500 ml | as 2025 #2 | open |
| 2022 #1 | category, returns, stores | Old system all year. `1701200 HOLIDAY VAP` appears only here, 27 lines in late Oct | as 2022 #1 | open |
| 2022 #2 | `item_no` | 1,523 items, 103,219 lines (4.5%), not in the catalog, e.g. 75211 `KINKY LIQUEUR` (3,937), 22216 `WOODFORD RESERVE BOURBON` (2,028) | as 2022 #2 | open |
| 2025 #3 | cost, retail | NULL all year | as 2025 #3 | open |
| 2025 #4 | `invoice_id` | Invoice + line, unique on all 2,291,276 lines | as 2025 #4 | open |
| 2025 #6 | `vendor_name` | 192 and 255 carry another company's name on a few lines (`SIDNEY FRANK IMPORTING`, `WILSON DANIELS LTD`), likely the item's earlier importer. 294 spelled two ways | as 2025 #6 | open |
| 2026 #4 | category | NULL on 3,130 lines of 215 items, all year, many gift packs, e.g. 100015 `FIREBALL BAG IN BOX` | as 2026 #4 | open |
| 2026 #6 | `im_desc`, `pack` | 4,008 (`item_no`, `im_desc`) pairs for 3,901 items | as 2026 #6 | open |
| 2026 #9 | text | Double spaces (sample): `vendor_name` 7,642, `store_address` 9,878, `store_name` 3,094, `im_desc` 4 | as 2026 #9 | open |

### 1. One item number with a letter

Two lines carry `x904631`, described `TANQUERAY GIN MINI - USE 904631 CODE`. Item `904631`
exists on other lines. Every other item number in every year is all digits.

| invoice_id | ordered_on | item_no | im_desc | bottles | dollars |
|---|---|---|---|---|---|
| INV-04204800002 | 2017-04-06 | x904631 | TANQUERAY GIN MINI - USE 904631 CODE | 12 | 261.96 |
| INV-04161100001 | 2017-04-04 | x904631 | TANQUERAY GIN MINI - USE 904631 CODE | 12 | 261.96 |

<details><summary>Query</summary>

```sql
select invoice_id, ordered_on, item_no, im_desc, sales_bottles, sales_dollars
from raw_iowa_data_hub.liquor_sales_2017 where item_no !~ '^\d+$';
```
</details>

### 2. Store location missing on 1.9% of lines

The location columns are NULL on 43,477 lines, against at most 4,764 in any later year. The
number falls through the year, from 41 stores in Jan to 8 in Dec. Six stores have no
location on any 2017 line, e.g. 2543 `HY-VEE FOOD STORE #1 / OTTUMWA` (7,017 lines; one line
has the address, with city `OTTUWMA`). Later years can fill them: 2543 has its address in 2018.
A store dimension built across years can fill the rest.

| Month | Stores | Lines |
|---|---|---|
| 2017-01 | 41 | 5,399 |
| 2017-06 | 22 | 4,337 |
| 2017-12 | 8 | 1,342 |

<details><summary>Query</summary>

```sql
select substr(ordered_on, 1, 7) as month, count(distinct store_no) as stores, count(*)
from raw_iowa_data_hub.liquor_sales_2017 where store_address is null group by 1 order by 1;
```
</details>
