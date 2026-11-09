# raw_iowa_data_hub.liquor_sales_2012

Profiled 2026-11-07, data as of 2026-11-07 00:03 +07. 2,082,059 rows, ordered
2012-01-03 – 2012-12-31. No row repeats another. One row is one invoice line, as in 2026.
This is the oldest year.

Same as [2013](liquor_sales_2013.md), and through it the later years, except where listed
below. The whole year is on the old system (2016 #1). Same method and checks. The 5% sample
has 102,961 rows.

## Columns

Only the columns that differ from 2013.

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `invoice_id` | text | `378900001`, `4295S05259700001`, `306831300001` | | 296 lines in four other shapes (#2). Unique |
| `ordered_on` | text → date | | 2012-01-03 – 2012-12-31 | no Sunday; 1 Saturday (9,741 rows); Fridays on 26 days |
| `store_no`, `store_name` | text | | | 1,226 stores, one name each all year |
| `county_fips_code`, `county_name` | text | | | NULL on 3,599 lines with an address: stores 3782 (1,910) and 4247 (1,689) (2016 #4) |
| `category_code` | text | | | 75 codes, all 7 digits; NULL on 284 lines |
| `vendor_number`, `vendor_name` | text | | | 120 vendors, one name each; 2 digits on 537,420 lines (2016 #1) |
| `item_no` … `bottle_volume_ml` | text | | | 3,146 items, one description, pack and volume each all year |
| `bottle_volume_ml` | text → int | | 12 – 3,000 | no 0 |
| `sales_bottles` | text → int | | 1 – 15,000 | |
| `sales_dollars` | text → numeric | | 0 – 254,100 | NULL on 10 lines (#1); $0 on 3,080 lines (2018 #2) |
| `sales_liters` | text → numeric | | 0.07 – 15,000 | |

- Top lines: Hy-Vee 2633 ordered 15,000 bottles of Captain Morgan for $254,100, twice
  (2012-06-04 and 2012-12-03).
- `sales_bottles` bins (sample): 1–12 93,079, 13–48 8,480, 49–120 1,076, 121–600 311,
  `>600` 15.

## Issues

| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `sales_dollars` | NULL on 10 lines of 2 minis, 2012-01-30 – 31 | ask: the only NULL amount in any year | open |
| 2 | `invoice_id` | 296 lines in four other shapes, some without the `S` | accept: unique; do not parse it | open |
| 2018 #2 | `sales_dollars` | $0 on 3,080 lines. 3,072 are Luxco items in Feb 2012 (e.g. `PARAMOUNT SLOE GIN`): 2,451 of 8,406 Paramount lines that month | as 2018 #2, ask whether Feb 2012 Luxco lines lost their price (README Q18) | open |
| 2016 #1 | invoice, category, vendor | Old system all year | as 2016 #1 | decided |
| 2016 #3 | `store_zip_code` | `712-2` on 1,485 lines | as 2016 #3 | open |
| 2016 #4 | county | NULL with an address on 3,599 lines | as 2016 #4 | decided |
| 2022 #2 | `item_no` | 1,794 items, 221,386 lines (10.6%), not in the catalog. Most are 73050 `RUMCHATA` (11,992) | as 2022 #2 | open |
| 2025 #2 | `bottle_volume_ml` | Pack total for the 2025 #2 items, e.g. 48102 at 1,200 | as 2025 #2 | open |
| 2025 #3 | cost, retail | NULL all year | as 2025 #3 | open |
| 2026 #4 | category | NULL code on 284 lines of 4 items, e.g. 3657 `HERRADURA GOLD REPOSADO 6PAK` | as 2026 #4 | open |

### 1. Dollars missing on 10 lines

`sales_dollars` is NULL on 10 lines, the only NULL amounts in 2012 – 2026. Bottles and liters
are present.

| item_no | im_desc | Lines | Ordered on |
|---|---|---|---|
| 38180 | TITOS HANDMADE MINI | 7 | 2012-01-30 – 2012-01-31 |
| 35920 | PEARL WEDDING CAKE VODKA MINI | 3 | 2012-01-30 – 2012-01-31 |

<details><summary>Query</summary>

```sql
select invoice_id, ordered_on, item_no, im_desc, sales_bottles, sales_dollars
from raw_iowa_data_hub.liquor_sales_2012 where sales_dollars is null;
```
</details>

### 2. Four other invoice formats

| Shape | Lines | Stores | Days | Example |
|---|---|---|---|---|
| 9 digits, no `S` | 189 | 3 | 3 (2012-02-29 – 2012-10-17) | `378900001` |
| 12 digits, no `S` | 31 | 1 | 1 (2012-07-30) | `306831300001` |
| 4 digits + `S` + 11 digits | 70 | 1 | 1 (2012-04-26) | `4295S05259700001` |
| `S999999-99999999` | 6 | 1 | 1 (2012-10-29) | `S086270-00100001` |

The usual shape is `S` + 11 digits, as in 2013–2016. All stay unique.

<details><summary>Query</summary>

```sql
select regexp_replace(invoice_id, '\d', '9', 'g') as shape, count(*), count(distinct store_no),
       count(distinct ordered_on), min(invoice_id), max(invoice_id)
from raw_iowa_data_hub.liquor_sales_2012 where invoice_id !~ '^S\d{11}$' group by 1;
```
</details>
