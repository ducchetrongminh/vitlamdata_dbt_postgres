# raw_iowa_data_hub.liquor_sales_2025

Profiled 2026-11-07, data as of 2026-11-07 00:03 +07. 3,007,599 rows, ordered
2025-01-01 – 2025-12-31. The publisher counts 2,490,620: the export repeats 516,986 lines (#1).
One row is one invoice line, as in 2026.

Same as [2026](liquor_sales_2026.md), except where listed below. Same method and checks.
The 5% sample has 151,907 rows. Counts in the issues are on distinct rows unless stated,
so the repeated lines of #1 do not inflate them.

Publisher docs: dataset 1262. Same source SQL as 2026, for 2025. The column descriptions are
correct, not shifted as on the 2026 page. Cost and retail are described as "Data not
available before 7/1/2025" (#3).

## Columns

Only the columns that differ from 2026. Every other column is as in 2026.

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `invoice_id` | text | `INV-78191800001`, `INV-903316`, `RINV-05593000013` | | invoice + line number, unique, until 2025-08-29; invoice only from 2025-09-01 (#4) |
| `ordered_on` | text → date | | 2025-01-01 – 2025-12-31 | Sundays most weeks (50 days, 50,427 rows), 1 Saturday (2025-12-27, 1,285 rows) |
| `store_no` | text | `2633`, `010038` | | 2,243 stores: 1,722 with 4 digits, 521 with 6 digits (010003–010736) |
| `store_name` | text | `KUM & GO #1074 / WDM`, `MAVERIK #5364 / WDM` | | 2,338 names (2026 #5) |
| `store_address` … `county_name` | text | | | NULL on 1,553 distinct lines of 8 stores (2026 #5) |
| `category_code` | text | | | 44 codes, no NULL |
| `category_name` | text | `AMERICAN CORDIALS & LIQUEURS` | | 48 names: 4 codes renamed 2025-07-01 (#5) |
| `vendor_number` | text | | | 232 vendors, 234 names (#6) |
| `item_no` | text | | | 5,048 items; no orphans vs `liquor_products` |
| `bottle_volume_ml` | text → int | | 20 – 5,250 | pack total, not bottle, for 18 items before 2025-09-01 (#2) |
| `state_bottle_cost` | text → numeric | | 0 – 3,750 | NULL before 2025-07-01 (#3); whole numbers Nov–Dec (2026 #2) |
| `state_bottle_retail` | text → numeric | | 1 – 5,625 | as cost |
| `sales_bottles` | text → int | | -528 – 13,200 | |
| `sales_dollars` | text → numeric | | -2,213.28 – 260,832 | |
| `sales_liters` | text → numeric | | -189 – 13,200 | |
| `sales_gallons` | text → numeric | | -49.92 – 3,487.07 | |

- Nulls: no NULL category. Cost and retail NULL on 1,213,529 lines (#3).
- Casts: clean, as 2026.
- Top lines: Hy-Vee store 2633 ordered 13,200 bottles of Tito's for $260,832 twice, on
  2025-01-27 and 2025-04-21. The most negative line is a return of 528 Fireball,
  `RINV-05593000013`.
- `sales_bottles` bins (sample): `<0` 136, 1–12 129,465, 13–48 18,752, 49–120 2,406,
  121–600 1,091, `>600` 57.
- Text (sample): no non-ASCII in `im_desc`, unlike 2026.

## Issues

| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | all | The export repeats every line ordered 2025-07-29 – 2025-10-14: 516,986 extra rows | drop whole-row repeats in intermediate (README Q9) | decided |
| 2 | `bottle_volume_ml` | 18 multi-pack items carry the pack's total ml until 2025-08-29, a bottle's ml after | clean in intermediate: type 1, the latest volume; staging recomputes liters (README Q15) | decided |
| 3 | `state_bottle_cost`, `state_bottle_retail` | NULL before 2025-07-01, as the publisher states | accept | open |
| 4 | `invoice_id` | Invoice + line number, unique, until 2025-08-29. From 2025-09-01 as 2026 #1 | accept: `invoice_id` is the line key before 2025-09-01 | open |
| 5 | `category_name` | 4 names renamed from plural to singular on 2025-07-01, same code | clean in intermediate: key on `category_code`, take the latest name | decided |
| 6 | `vendor_name` | 2 vendors renamed during the year | accept: the vendor dim takes the latest name | open |
| 2026 #2 | cost, retail, dollars, liters, gallons | Whole numbers from 2025-11-01: all 441,822 lines in Nov–Dec, 122 zero cost, 98,147 zero liters | as 2026 #2 | open |
| 2026 #3 | `sales_dollars` | ≠ bottles × retail on 21,885 of 835,262 priced lines in Jul–Oct (2.6%); 14,198 in Jul. Retail ≠ 1.5 × cost on 119 (Jul) and 102 (Aug) lines | as 2026 #3 | open |
| 2026 #4 | category | 135 extra (`item_no`, `category_code`) pairs; no NULL category | as 2026 #4 | open |
| 2026 #5 | store columns | Location NULL on 8 stores' lines, 010206 on all 1,340; zip `57222` on 232 lines; 2201 and 2248 carry two names on one day, same address | as 2026 #5 | decided |
| 2026 #6 | `im_desc`, `pack` | 5,145 (`item_no`, `im_desc`) pairs for 5,048 items; 29 extra pack/volume pairs, 19 of them volume (#2) | as 2026 #6 | open |
| 2026 #7 | returns | 2,401 `RINV-` lines, 4 positive; 3 `INV-` lines negative | as 2026 #7 | open |
| 2026 #8 | `store_no` | as 2026 | as 2026 #8 | open |
| 2026 #9 | text | Double spaces (sample): `vendor_name` 31,808, `store_address` 6,727, `store_name` 2,189, `im_desc` 156 | as 2026 #9 | decided |

### 1. The export repeats a slice of lines

The export zip has 5 CSV parts. Part 5 is a second copy of 516,974 lines of part 3, ordered
2025-07-29 – 2025-10-14. Our loader reads each part once, so the table holds every one of those
lines twice:

| Part | Rows | Ordered on |
|---|---|---|
| 0001 | 726,869 | 2025-01-01 – 2025-04-23 |
| 0002 | 551,284 | 2025-04-23 – 2025-07-10 |
| 0003 | 697,191 | 2025-07-10 – 2025-10-22 |
| 0004 | 515,276 | 2025-10-22 – 2025-12-31 |
| 0005 | 516,979 | 2025-07-29 – 2025-10-14, all in 0003 |

The table has 2,490,613 distinct rows. Seven lines repeat inside the data, as in 2026 #1,
which brings it to 2,490,620, exactly the publisher's count. So the publisher's table is
right, and only the export repeats lines.

The repeated slice moves when the export is rebuilt. The load of 2026-11-05 held 2,978,001
rows, with lines from 2025-10-27 to 2025-12-31 doubled instead. A fixed date filter cannot
remove it. A whole-row dedupe would also drop the 7 real repeats. Skipping a part whose rows
all appear in an earlier part fixes it at the source. Other years' exports may do the same.

<details><summary>Query</summary>

```sql
with g as (
  select substr(ordered_on, 1, 7) as month, count(*) as n
  from raw_iowa_data_hub.liquor_sales_2025
  group by invoice_id, ordered_on, store_no, store_name, store_address, store_city,
           store_zip_code, county_fips_code, county_name, category_code, category_name,
           vendor_number, vendor_name, item_no, im_desc, pack, bottle_volume_ml,
           state_bottle_cost, state_bottle_retail, sales_bottles, sales_dollars,
           sales_liters, sales_gallons)
select month, sum(n) as rows, count(*) as distinct_rows, sum(n - 1) as extra, max(n)
from g group by 1 order by 1;
```

The parts were counted from a fresh download of
`https://data.iowa.gov/api/dataset-download?path=datasets%2F1262%2Frows.csv`.
</details>

### 2. `bottle_volume_ml` is the pack's volume before 2025-09-01

On 2025-09-01, 18 items change `bottle_volume_ml` from the whole unit's volume to one
bottle's. The item and pack stay the same. Liters follow the volume, so these items' liters
before Sep are larger by the bottles per unit:

| item_no | im_desc | pack | ml until 2025-08-29 | ml from 2025-09-01 |
|---|---|---|---|---|
| 48102 | HENNESSY VS 100ML | 8 | 1,200 | 100 |
| 68039 | BAILEYS ORIGINAL IRISH CREAM 100ML | 4 | 2,400 | 100 |
| 67042 | TWISTED SHOTZ MIAMI VICE | 1 | 1,800 | 25 |
| 100572 | JOHNNIE WALKER 200ML COLLECTION PACK | 6 | 800 | 200 |
| 78186 | TWISTED TEA WHISKEY | 12 | 750 | 25 |

11 of the 18 are Twisted Shotz party packs, mostly 1,800 ml before and 25 after. The two
Twisted Tea items also drop to 25 ml: 78186 from 750, 78187 `TWISTED TEA WHISKEY MINI` from
50. Those two may be wrong rather than a pack total. The 2026 lines and the
current catalog use the bottle's ml. A 19th change, 933530 `DINGLE VODKA` 750 → 700 ml in
May, is a single correction.

<details><summary>Query</summary>

```sql
with s as (select item_no, im_desc, pack, bottle_volume_ml, count(*) as n,
                  min(ordered_on) as first_on, max(ordered_on) as last_on
           from raw_iowa_data_hub.liquor_sales_2025 group by 1, 2, 3, 4)
select * from s
where item_no in (select item_no from s group by 1 having count(distinct bottle_volume_ml) > 1)
order by item_no, first_on;
```
</details>

### 3. Cost and retail are NULL before 2025-07-01

All 1,213,529 lines from 2025-01-01 to 2025-06-30 have NULL `state_bottle_cost` and
`state_bottle_retail`, and no line after. The publisher's page says "Data not available
before 7/1/2025". `sales_dollars` is present on every line.

<details><summary>Query</summary>

```sql
select substr(ordered_on, 1, 7) as month, count(*), count(*) filter (where state_bottle_cost is null)
from raw_iowa_data_hub.liquor_sales_2025 group by 1 order by 1;
```
</details>

### 4. `invoice_id` is the line key until 2025-08-29

Until 2025-08-29, `invoice_id` is the 6-digit invoice number plus a 5-digit line number. On
distinct rows it is unique: 1,627,818 rows, 1,627,818 ids. From 2025-09-01 it is the invoice
number alone, as in 2026 #1.

| Format | Ordered on | Rows | Distinct `invoice_id` |
|---|---|---|---|
| `INV-99999999999` | 2025-01-01 – 2025-08-29 | 1,851,850 | 1,626,160 |
| `RINV-99999999999` | 2025-01-02 – 2025-08-29 | 1,866 | 1,658 |
| `INV-999999` | 2025-09-01 – 2025-12-31 | 1,152,889 | 42,219 |
| `RINV-999999` | 2025-09-02 – 2025-12-31 | 994 | 662 |

Rows include the repeats of #1.

<details><summary>Query</summary>

```sql
select regexp_replace(invoice_id, '\d', '9', 'g') as shape, count(*), count(distinct invoice_id),
       min(ordered_on), max(ordered_on)
from raw_iowa_data_hub.liquor_sales_2025 group by 1 order by 2 desc;
```
</details>

### 5. Four category names renamed on 2025-07-01

The names moved from plural to singular under the same code. From 2025-07-01 they match
2026 and `liquor_products`:

| category_code | Until 2025-06-30 | From 2025-07-01 |
|---|---|---|
| 1081300 | `AMERICAN CORDIALS & LIQUEURS` | `AMERICAN CORDIALS & LIQUEUR` |
| 1082100 | `IMPORTED CORDIALS & LIQUEURS` | `IMPORTED CORDIALS & LIQUEUR` |
| 1091100 | `AMERICAN DISTILLED SPIRITS SPECIALTY` | `AMERICAN DISTILLED SPIRIT SPECIALTY` |
| 1092100 | `IMPORTED DISTILLED SPIRITS SPECIALTY` | `IMPORTED DISTILLED SPIRIT SPECIALTY` |

<details><summary>Query</summary>

```sql
select category_code, category_name, count(*), min(ordered_on), max(ordered_on)
from raw_iowa_data_hub.liquor_sales_2025 group by 1, 2 order by 1, 2;
```
</details>

### 6. Two vendors renamed

| vendor_number | Until | From | New name |
|---|---|---|---|
| 753 | `TYCOGA VINEYARD & WINERY, LLC`, 2025-02-24 | 2025-03-07 | `TYCOGA WINERY & DISTILLERY, LLC` |
| 895 | `BLUE MERANTI, LLC`, 2025-04-28 | 2025-05-01 | `BLUE MERANTI, LLC/HELMSMAN IMPORTS` |

<details><summary>Query</summary>

```sql
with s as (select vendor_number, vendor_name, count(*) as n, min(ordered_on) as first_on,
                  max(ordered_on) as last_on
           from raw_iowa_data_hub.liquor_sales_2025 group by 1, 2)
select * from s where vendor_number in (select vendor_number from s group by 1 having count(*) > 1)
order by 1, first_on;
```
</details>
