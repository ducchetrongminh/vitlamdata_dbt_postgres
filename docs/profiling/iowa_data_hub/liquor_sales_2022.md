# raw_iowa_data_hub.liquor_sales_2022

Profiled 2026-11-07, data as of 2026-11-07 00:03 +07. 2,958,969 rows, ordered
2022-01-02 – 2022-12-30. The export repeats 394,404 of them (2025 #1), so 2,564,565 rows are
distinct. One row is one invoice line, as in 2026.

Same as [2023](liquor_sales_2023.md), and through it [2024](liquor_sales_2024.md),
[2025](liquor_sales_2025.md) and [2026](liquor_sales_2026.md), except where listed below. Same
method and checks. The 5% sample has 149,719 rows. Counts are on all rows, repeats included,
unless stated.

## Columns

Only the columns that differ from 2023.

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `invoice_id` | text | `INV-43470400126` | | `RINV-` from 2022-07-20 only (#1) |
| `ordered_on` | text → date | | 2022-01-02 – 2022-12-30 | 40 Sundays but only 8,557 rows; 7 Saturdays (34,337 rows) |
| `store_no` | text | | | 2,036 stores. 6-digit numbers from 2022-07-22 only, 73 stores up to 010106 (#1) |
| `store_name` | text | `HY-VEE FOOD STORE #1 (1013) / AMES` | | 2,113 names. Hy-Vee stores add their own number in brackets in Dec 2022 (2026 #5) |
| `store_zip_code` | text | | | NULL on 1,866 lines: 1,844 with the address, 22 alone (2026 #5) |
| `category_code` | text | `1082000`, `1071100`, `1700000` | | 57 codes: 10 group codes (2024 #1) and 4 codes replaced on 2022-07-18 (#1) |
| `vendor_number`, `vendor_name` | text | | | 233 vendors, 237 names: 4 renamed (2025 #6) |
| `item_no` | text | | | 4,786 items; 2 not in `liquor_products` (#2) |
| `pack` | text → int | | 1 – 120 | 120 on one line: `BLUE CHAIR BAY COCONUT SPICED RUM CREAM MINIS` |
| `sales_bottles` | text → int | | -360 – 13,200 | no negative line before 2022-07-20 (#1) |
| `sales_dollars` | text → numeric | | -9,720 – 250,932 | Tito's 13,200 bottles for $250,932: a lower price than later years |
| `sales_liters` | text → numeric | | -630 – 13,200 | |
| `sales_gallons` | text → numeric | | -166.42 – 3,487.07 | |

- `sales_bottles` bins (sample): `<0` 71, 1–12 130,498, 13–48 16,034, 49–120 2,074,
  121–600 977, `>600` 65.

## Issues

| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `category_code`, `invoice_id`, `store_no` | A system change on 2022-07-18 (guess): category codes recoded, returns and 6-digit store numbers start | clean in staging: type 1, the item's latest category. Invoice numbers 450000–454720 reused (README Q8) (README Q17) | decided |
| 2 | `item_no` | 2 items, 12 lines, not in `liquor_products` | accept: build those products from the sales lines | open |
| 2025 #1 | all | The export repeats every line from midway through 2022-11-11 to 2022-12-30: 145,222 extra rows in Nov, 249,182 in Dec | as 2025 #1 | open |
| 2024 #1 | `category_code` | Group codes are common before #1: 1082000 carries 27,218 lines | see #1 | decided |
| 2025 #2 | `bottle_volume_ml` | as 2024, e.g. 48102 at 1,200 | as 2025 #2 | open |
| 2025 #3 | cost, retail | NULL all year | as 2025 #3 | open |
| 2025 #4 | `invoice_id` | Invoice + line, unique on the 2,564,565 distinct lines | as 2025 #4 | open |
| 2025 #6 | `vendor_name` | 4 renamed: 079, 306, 521, 620 | as 2025 #6 | open |
| 2026 #5 | store columns | Location NULL on 1,844 lines of 8 stores, all with the location on other lines, e.g. 010039's first 935 lines. 010081 has no zip on 22 lines on 2022-10-31. Zip `57222` on 348 lines | as 2026 #5 | open |
| 2026 #6 | `im_desc`, `pack` | 4,859 (`item_no`, `im_desc`) pairs for 4,786 items; 11 items change pack or volume | as 2026 #6 | open |
| 2026 #7 | returns | 1,446 `RINV-` lines, 2 positive; no negative `INV-` line | as 2026 #7 | open |
| 2026 #9 | text | Double spaces (sample): `vendor_name` 24,658, `store_address` 8,979, `store_name` 2,176, `im_desc` 197 | as 2026 #9 | open |

### 1. A system change on 2022-07-18

Three things start or change within days of each other, so the publisher likely changed
its system then (guess).

Category codes. Until 2022-07-15, some categories use a different code than after:

| Until 2022-07-15 | Lines | From 2022-07-18 | Name |
|---|---|---|---|
| 1071100 | 43,076 | 1071000 | `COCKTAILS/RTD` |
| 1901200 | 1,173 | 1901000 | `SPECIAL ORDER ITEMS` |
| 1700000 | 1,560 | 1701100 | `TEMPORARY & SPECIALTY PACKAGES` (1701100 also used before) |
| 1082000 | 27,050 Jan–Jul | 1082100 | `IMPORTED CORDIALS & LIQUEURS`. 1082100 also used before, on fewer lines |

Group codes ending `000` (2024 #1) appear more often than in later years: `1012000
IMPORTED WHISKIES`, `1031000 AMERICAN VODKAS`, `1042000 IMPORTED GINS`, `1070000
COCKTAILS/RTD`, `1090000 DISTILLED SPIRITS SPECIALTY`, `1091000 AMERICAN DISTILLED SPIRITS
SPECIALTY`, plus the four of 2024. Most have under 30 lines. `1032000` has 501 and
`1081000` 266.

Returns. The first `RINV-` line and the first negative line are both on 2022-07-20. Before,
there is no return at all. Returns were likely not exported, or were netted off
another way (guess).

Store numbers. The first 6-digit store number (`010…`) is on 2022-07-22. New stores get
6-digit numbers from then on.

<details><summary>Query</summary>

```sql
select category_code, category_name, count(*), min(ordered_on), max(ordered_on)
from raw_iowa_data_hub.liquor_sales_2022 group by 1, 2 order by 1, 2;

select min(ordered_on) filter (where invoice_id like 'RINV-%') as first_return,
       min(ordered_on) filter (where sales_bottles::int < 0) as first_negative,
       min(ordered_on) filter (where store_no ~ '^010\d{3}$') as first_6_digit_store
from raw_iowa_data_hub.liquor_sales_2022;
```
</details>

### 2. Two items are not in the catalog

`liquor_products` is today's catalog. Two 2022 items are no longer in it:

| item_no | im_desc | vendor_name | Lines | Ordered on |
|---|---|---|---|---|
| 638071 | STATE VODKA MINI | MIDWEST LIQUOR COMPANY | 11 | 2022-01-13 – 2022-01-18 |
| 980037 | BOLS NOYAUX | MHW LTD | 1 | 2022-05-16 |

The sales lines carry enough to build them: description, vendor, pack, volume, category.

<details><summary>Query</summary>

```sql
select s.item_no, s.im_desc, s.vendor_name, count(*), min(ordered_on), max(ordered_on)
from raw_iowa_data_hub.liquor_sales_2022 s
left join (select distinct item_no from raw_iowa_data_hub.liquor_products) p using (item_no)
where p.item_no is null group by 1, 2, 3;
```
</details>
