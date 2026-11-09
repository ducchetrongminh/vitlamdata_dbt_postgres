# raw_iowa_data_hub.liquor_sales_2013

Profiled 2026-11-07, data as of 2026-11-07 00:03 +07. 2,063,763 rows, ordered
2013-01-02 – 2013-12-31. No row repeats another. One row is one invoice line, as in 2026.

Same as [2014](liquor_sales_2014.md), and through it the later years, except where listed
below. The whole year is on the old system (2016 #1). Same method and checks. The 5% sample
has 102,139 rows.

## Columns

Only the columns that differ from 2014.

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `invoice_id` | text | `S100064-00100001`, `S000056666600002` | | 524 lines in two other shapes (#1). Unique |
| `ordered_on` | text → date | | 2013-01-02 – 2013-12-31 | no Sunday; 5 Saturdays (30,705 rows); Fridays on 30 days |
| `store_no`, `store_name` | text | | | 1,274 stores, one name each all year |
| `county_fips_code`, `county_name` | text | | | NULL on 2,660 lines with an address: stores 3782 (1,430) and 4247 (1,230) (2016 #4) |
| `category_code` | text | `101220` | | 77 codes; `101220` on 4 lines (2014 #1). NULL on 298 lines |
| `vendor_number`, `vendor_name` | text | | | 124 vendors, one name each; 2 digits on 518,249 lines (2016 #1) |
| `item_no`, `im_desc`, `pack`, `bottle_volume_ml` | text | | | 3,359 items, one description, pack and volume each all year |
| `pack` | text → int | | 1 – 120 | |
| `bottle_volume_ml` | text → int | | 0 – 7,580 | 0 on 1 line (2015 #3); 7,580 on 1 line (#3) |
| `sales_bottles` | text → int | | 1 – 11,124 | |
| `sales_dollars` | text → numeric | | 0 – 196,004.88 | 4 lines with $0 (2018 #2); an overpriced gift set (#2) |

- Top lines: Hy-Vee 2633 ordered 11,124 bottles of Captain Morgan for $196,004.88 on
  2013-06-24.
- `sales_bottles` bins (sample): 1–12 92,067, 13–48 8,693, 49–120 1,069, 121–600 293,
  `>600` 17.

## Issues

| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `invoice_id` | 352 lines of 4 stores as `S999999-99999999`; 172 lines of 1 store on 2013-07-08 as `S` + 15 digits | accept: unique; do not parse the line number from it | open |
| 2 | `sales_dollars` | 3984 `ABSOLUT W/4-50MLS` sells at $206.07 and $206.82 a unit on all 287 lines, Oct–Dec: $820,193 in all | accept: keep the amount, flag the item's 2013 lines (README Q20) | decided |
| 3 | `bottle_volume_ml` | 7,580 ml on 1 line of 917836 `EARLY TIMES BOURBON 354`, priced like a 750 ml bottle | clean in staging: guess 750; ask | open |
| 2014 #1 | `category_code` | `101220` on 4 lines of `CRAIGELLACHIE` | as 2014 #1 | open |
| 2015 #3 | `bottle_volume_ml` | 0 on 1 line of 905230 `RONDIAZ DSS LEMON RUM` | as 2015 #3 | open |
| 2016 #1 | invoice, category, vendor | Old system all year | as 2016 #1 | decided |
| 2016 #3 | `store_zip_code` | `712-2` on 1,614 lines | as 2016 #3 | open |
| 2016 #4 | county | NULL with an address on 2,660 lines | as 2016 #4 | open |
| 2018 #2 | `sales_dollars` | $0 on 4 lines (Apr, Jul) | as 2018 #2 | open |
| 2022 #2 | `item_no` | 1,880 items, 209,971 lines (10.2%), not in the catalog. Most are 73050 `RUMCHATA` (11,297 lines), today under another number (guess) | as 2022 #2 | open |
| 2025 #2 | `bottle_volume_ml` | Pack total for the 2025 #2 items, e.g. 48102 at 1,200 | as 2025 #2 | open |
| 2025 #3 | cost, retail | NULL all year | as 2025 #3 | open |
| 2026 #4 | category | NULL code on 298 lines of 4 items, e.g. 3657 `HERRADURA GOLD REPOSADO 6PAK` | as 2026 #4 | open |

### 1. Two other invoice formats

Besides `S` + 11 digits, two shapes occur:

| Shape | Lines | Stores | Days | Example |
|---|---|---|---|---|
| `S999999-99999999` | 352 | 4 | 7, 2013-01-14 – 2013-10-24 | `S100064-00100001` |
| `S` + 15 digits | 172 | 1 | 2013-07-08 | `S000056666600002` |

Both stay unique. The line number is not in the same place as in the usual shape.

<details><summary>Query</summary>

```sql
select regexp_replace(invoice_id, '\d', '9', 'g') as shape, count(*), count(distinct store_no),
       count(distinct ordered_on), min(invoice_id), max(invoice_id)
from raw_iowa_data_hub.liquor_sales_2013 where invoice_id !~ '^S\d{11}$' group by 1;
```
</details>

### 2. A gift set sold at $206 a unit

Item 3984 `ABSOLUT W/4-50MLS` (a 750 ml bottle with four 50 ml minis, pack 1) is billed at
$206.07 a unit in Oct and $206.82 from Nov, on every one of its 287 lines. The largest line
is 540 units for $111,277.80 (`S15210800214`, store 2561). `ABSOLUT SWEDISH VODKA 80 PRF` 750 ml
sells at $16.65 a bottle in 2013, so the price looks ten times too high (guess). The item adds $820,193 to 2013's sales.

| Unit price | Lines | Dollars | Ordered on |
|---|---|---|---|
| 206.07 | 63 | 696,928.74 | 2013-10-08 – 2013-10-31 |
| 206.82 | 224 | 123,264.72 | 2013-11-05 – 2013-12-31 |

<details><summary>Query</summary>

```sql
select round(sales_dollars::numeric / sales_bottles::numeric, 2) as per_unit, count(*),
       sum(sales_dollars::numeric), min(ordered_on), max(ordered_on)
from raw_iowa_data_hub.liquor_sales_2013 where item_no = '3984' group by 1;
```
</details>

### 3. A volume of 7,580 ml

One line of 917836 `EARLY TIMES BOURBON 354` (`S14601400001`, 2013-09-17) has 7,580 ml: 12
bottles for $170.28, $14.19 a bottle, a 750 ml price. Its liters (91) are ten times too high.

<details><summary>Query</summary>

```sql
select * from raw_iowa_data_hub.liquor_sales_2013 where item_no = '917836';
```
</details>
