# raw_iowa_data_hub.liquor_sales_2025, liquor_sales_2026

2026 is now profiled on its own in [liquor_sales_2026.md](liquor_sales_2026.md). This file stays
until 2025 gets its own file.

Profiled 2026-11-06. Covers `liquor_sales_2025` and `liquor_sales_2026` only, not the other years. Both
tables share one schema (only the column order differs).

| Table | Rows | Ordered on | Loaded (load id) | Publisher row count |
|---|---|---|---|---|
| `liquor_sales_2025` | 2,978,001 | 2025-01-01 – 2025-12-31 | 2026-11-05 10:42 +07 (`1793850173.569915`) | 2,490,620 (#2) |
| `liquor_sales_2026` | 2,029,764 | 2026-01-01 – 2026-10-30 | 2026-11-06 06:52 +07 (`1793922757.4360197`) | 2,029,764 |

One row is one line of a store's order from the state (an invoice line). The publisher
says `invoice_id` identifies the line. That holds only before 2025-09-01 (#1).

Method: key, row counts, null counts, cast checks, ranges and cross-column checks are full
scans. Value distributions, shapes and text checks use a 5% sample,
`TABLESAMPLE SYSTEM (5) REPEATABLE (42)` (150,227 rows in 2025, 99,840 in 2026).

Publisher docs: the dataset pages (data.iowa.gov datasets 1262 and 1263) give a column
description for each column, the source SQL (`SELECT * FROM
iowa_data_hub_gold_prod.liquor_sales_combined WHERE ordered_on` in the year), `invoice_id` as
the unique identifier and `ordered_on` as the record date. On the 2026 page, the descriptions
from `store_name` to `sales_bottles` are shifted by one column. The 2025 page is correct.

## Columns

Ranges cover both years. A value differs by year only where the note says so.

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `invoice_id` | text | `INV-78191800001`, `INV-903316`, `INV-0990155`, `RINV-060442` | | format changes twice; not unique from 2025-09-01 (#1). `RINV-` = returns (#9) |
| `ordered_on` | text → date | | 2025-01-01 – 2026-10-30 | all `YYYY-MM-DD`; Mon–Fri, a few Sat and Sun |
| `store_no` | text | `2633`, `5444`, `010038` | | 4 digits (2106–9049) or 6 digits starting `010`: keep as text (#7) |
| `store_name` | text | `HY-VEE #3 / BDI / DES MOINES`, `MAVERIK #5364 / WDM` | | changes over time per store (#7) |
| `store_address` | text | `330 JORDAN CREEK PARKWAY`, `1725  74TH ST` | | 2,065 NULL (2025), 2,582 NULL (2026) (#7) |
| `store_city` | text | `WEST DES MOINES`, `MARSHALLTOWN` | | NULL with the address |
| `store_zip_code` | text | `50266`, `52337` | | always 5 digits; NULL with the address; one typo `57222` (#7) |
| `county_fips_code` | text | `19127`, `19153` | | 19001–19197: Iowa state code + county; NULL with the address |
| `county_name` | text | `POLK`, `MARSHALL` | | 99 counties, 1:1 with FIPS; NULL with the address |
| `category_code` | text | `1011200`, `1701100` | | 44 codes, 7 digits; 26 NULL in 2026 (#6) |
| `category_name` | text | `STRAIGHT BOURBON WHISKIES`, `TEMPORARY & SPECIALTY PACKAGES` | | upper case; 4 names renamed 2025-07-01 (#6) |
| `vendor_number` | text | `035`, `260` | | always 3 digits: keep as text (leading zeros); 232 (2025), 207 (2026) |
| `vendor_name` | text | `DIAGEO AMERICAS`, `BACARDI USA INC` | | 2 vendors renamed during 2025; double spaces (#11) |
| `item_no` | text | `38177`, `88296`, `102754` | | all digits, 3–6 long; 5,048 items (2025), 4,792 (2026); no orphans vs `liquor_products` |
| `im_desc` | text | `TITOS HANDMADE VODKA`, `GREEN SPOT USE CODE 14820` | | upper case; changes over time per item (#8) |
| `pack` | text → int | | 1 – 48 | changes over time for some items (#8) |
| `bottle_volume_ml` | text → int | | 20 – 5,250 | no zeros |
| `state_bottle_cost` | text → numeric | | 0 – 3,750 | NULL before 2025-07-01 (#4); whole numbers Nov 2025 – Jan 2026 (#3) |
| `state_bottle_retail` | text → numeric | | 1 – 5,625 | as cost |
| `sales_bottles` | text → int | | -528 – 13,200 | negatives are returns (#9) |
| `sales_dollars` | text → numeric | | -3,240 – 260,832 | ≠ bottles × retail on 1–3% of lines (#5) |
| `sales_liters` | text → numeric | | -189 – 13,200 | = bottles × volume / 1,000, except #3 |
| `sales_gallons` | text → numeric | | -49.92 – 3,487.07 | = bottles × volume / 3,785.41, except #3 |
| `_dlt_load_id` | text | `1793850173.569915` | | one load per table (replace) |
| `_dlt_id` | text | `OkklfS5Eg+c5+Q` | | dlt row id, unique |

- Nulls: none, except the store location columns (#7), cost and retail before 2025-07-01 (#4)
  and category in 26 rows (#6).
- Casts: clean. All 8 numeric columns match `^-?[0-9]+(\.[0-9]+)?$` and `ordered_on` matches
  `YYYY-MM-DD` on every row.
- The top lines are real. They are wholesale orders by the Hy-Vee distribution centre, store
  2633 `HY-VEE #3 / BDI / DES MOINES`, e.g. 13,200 bottles of Tito's for $260,832.
- `sales_bottles` bins (2026 sample): `<0` 75, 1–12 84,836, 13–48 12,483, 49–120 1,679,
  121–600 711, `>600` 56.
- Days: orders fall Mon–Fri. Sundays carry 7–6,704 lines, and 2025 has 1 Saturday, 2026 12.
  No future dates.
- `category_name`, `county_name`, `store_city` have no edge spaces, non-ASCII or lower case.
  `im_desc` has 1 (2025) and 8 (2026) non-ASCII rows in the sample.

## Issues

| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `invoice_id` | Unique per line until 2025-08-29. From 2025-09-01 it is the invoice number only, and no column set is unique | ask (README Q8). Staging needs a line key | open |
| 2 | all | 2025 only: every line from 2025-10-27 to 2025-12-31 is loaded twice, 487,388 extra rows | ask (README Q9). Then fix the load or dedupe in staging | open |
| 3 | cost, retail, dollars, liters, gallons | Rounded to whole numbers on lines from 2025-11-01 to 2026-01-31 | ask (README Q10). Liters and gallons can be recomputed in staging | open |
| 4 | `state_bottle_cost`, `state_bottle_retail` | NULL before 2025-07-01 (2025 only), as the publisher states | accept | open |
| 5 | `sales_dollars` | ≠ bottles × retail on 2.6% (2025) and 1.2% (2026) of lines outside #3 | ask (README Q11). Use `sales_dollars` as the amount | open |
| 6 | `category_code`, `category_name` | 4 names renamed 2025-07-01 under the same code; an item's category changes over time; 26 NULL | clean in staging: key on `category_code`, take the latest name; ask about the NULLs | open |
| 7 | store columns | Name and address change over time; location NULL on a few stores' lines; one zip typo | clean in staging: fill NULL location from the same store's other lines; `57222` → `52722` | open |
| 8 | `im_desc`, `pack` | Item description and pack change over time, including status codes and reuse for a new edition | accept: the line keeps the values as sold. Decide history in the product dim | open |
| 9 | `invoice_id`, measures | Returns are `RINV-` lines with negative bottles and dollars; 4 + 1 `RINV-` lines are positive, 4 + 2 `INV-` lines negative | accept | open |
| 10 | `store_no` | Two shapes: 4 digits and 6 digits starting `010` | accept: keep as text | open |
| 11 | text | Double spaces in `vendor_name`, `store_address`, `store_name`, `im_desc` | clean in staging: squeeze spaces | open |

### 1. `invoice_id` is not unique from 2025-09-01

The format changes on 2025-09-01. Before, it is the 6-digit invoice number plus a 5-digit line
number, and it is unique. From then, it is the invoice number alone. From 2026-09-14 the
number gains a leading zero (`INV-0990155`), which is cosmetic.

| Table | Format | Ordered on | Rows | Distinct `invoice_id` |
|---|---|---|---|---|
| 2025 | `INV-99999999999`, `RINV-99999999999` | 2025-01-01 – 2025-08-29 | 1,627,818 | 1,627,818 |
| 2025 | `INV-999999`, `RINV-999999` | 2025-09-01 – 2025-12-31 | 1,350,183 | 42,881 |
| 2026 | `INV-999999`, `INV-9999999`, `RINV-999999` | 2026-01-01 – 2026-10-30 | 2,029,764 | 105,920 |

(`invoice_id`, `item_no`) is not unique either: in 2026, 2,029,764 rows have 2,027,248 pairs.
An invoice can carry the same item on several lines, e.g. a full case plus loose bottles:

| invoice_id | item_no | im_desc | sales_bottles | sales_dollars |
|---|---|---|---|---|
| INV-0997227 | 17956 | EVAN WILLIAMS BLACK | 12 | 171 |
| INV-0997227 | 17956 | EVAN WILLIAMS BLACK | 1 | 14.25 |

Even the whole row is not unique: 2026 has 14 rows that repeat another row in every column.
They fall outside #2, so they are likely real repeated lines (guess). There is no natural line
key from 2025-09-01, and dlt's `_dlt_id` changes on every reload.

<details><summary>Query</summary>

```sql
-- swap the year to test the other table
select regexp_replace(invoice_id, '\d', '9', 'g') as shape, count(*), count(distinct invoice_id),
       min(ordered_on), max(ordered_on)
from raw_iowa_data_hub.liquor_sales_2026 group by 1 order by 2 desc;

select count(*) as rows, count(distinct invoice_id) as ids,
       count(distinct (invoice_id, item_no)) as invoice_items,
       count(distinct (invoice_id, ordered_on, store_no, store_name, store_address, store_city,
                       store_zip_code, county_fips_code, county_name, category_code, category_name,
                       vendor_number, vendor_name, item_no, im_desc, pack, bottle_volume_ml,
                       state_bottle_cost, state_bottle_retail, sales_bottles, sales_dollars,
                       sales_liters, sales_gallons)) as distinct_rows
from raw_iowa_data_hub.liquor_sales_2026;
```
</details>

### 2. 2025 lines from 2025-10-27 on are loaded twice

`liquor_sales_2025` has 2,978,001 rows, but the publisher's page counts 2,490,620. Grouping on every
column, all lines from midway through 2025-10-27 to 2025-12-31 appear exactly twice. Two
groups appear 4 times (a real repeated line, doubled).

| Month | Rows | Distinct rows | Extra rows |
|---|---|---|---|
| 2025-01 – 2025-08 | 1,627,818 | 1,627,818 | 0 |
| 2025-09 | 206,162 | 206,158 | 4 |
| 2025-10 | 260,373 | 214,815 | 45,558 |
| 2025-11 | 390,622 | 195,311 | 195,311 |
| 2025-12 | 493,026 | 246,511 | 246,515 |

2,978,001 − 487,388 = 2,490,613, 7 rows under the publisher's count. So the publisher's
table is likely not doubled, but the CSV export or the load is (guess). It was not checked
by downloading the export again. `liquor_sales_2026` matches the publisher's count exactly, and
its 14 repeated rows are #1, not this issue.

A dedupe on whole rows would also drop the real repeated lines (#1). In the doubled range,
halving each group's count keeps them.

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
</details>

### 3. Money and volume are whole numbers from 2025-11-01 to 2026-01-31

On every line ordered in Nov 2025 – Jan 2026, cost, retail, dollars, liters and gallons are
whole numbers. Each is rounded on its own, so they no longer agree. The rest of the time,
liters and gallons equal bottles × volume on every line. The period spans both tables.

| invoice_id | ordered_on | im_desc | bottles | ml | cost | retail | dollars | liters | gallons |
|---|---|---|---|---|---|---|---|---|---|
| INV-892249 | 2025-12-02 | BURNETTS VODKA 80PRF | 6 | 1750 | 9 | 13 | 81 | 10 | 2 |
| INV-892254 | 2025-12-02 | HAWKEYE VODKA MINI | 12 | 50 | 4 | 6 | 81 | 0 | 0 |

Burnetts: 6 × 13 = 78, so the line's real retail was about 13.49. The 0.6 l of Hawkeye minis
shows as 0 liters. This rounding is the source of all 286 zero `state_bottle_cost` rows (244 in
2025, 42 in 2026), and of the zero liters and gallons on small lines.

| Month | Lines | Liters ≠ bottles × ml / 1000 | Dollars ≠ bottles × retail |
|---|---|---|---|
| 2025-10 | 260,373 | 0 | 6,033 |
| 2025-11 | 390,622 | 255,644 | 252,754 |
| 2025-12 | 493,026 | 316,022 | 325,040 |
| 2026-01 | 182,995 | 120,240 | 120,224 |
| 2026-02 | 174,168 | 0 | 945 |

Liters and gallons can be recomputed in staging from `sales_bottles` and `bottle_volume_ml`.
Cost, retail and dollars cannot be recovered from these tables.

<details><summary>Query</summary>

```sql
-- swap the year to test the other table
select substr(ordered_on, 1, 7) as month, count(*) as lines,
       count(*) filter (where abs(sales_liters::numeric
                        - sales_bottles::numeric * bottle_volume_ml::numeric / 1000) > 0.01) as liters_off,
       count(*) filter (where abs(sales_dollars::numeric
                        - sales_bottles::numeric * state_bottle_retail::numeric) > 0.01) as dollars_off,
       count(*) filter (where (state_bottle_cost || state_bottle_retail || sales_dollars || sales_gallons) ~ '\.') as has_decimals,
       count(*) filter (where state_bottle_cost::numeric = 0) as zero_cost
from raw_iowa_data_hub.liquor_sales_2025 group by 1 order by 1;
```
</details>

### 4. Cost and retail are NULL before 2025-07-01

All 1,213,529 lines from 2025-01-01 to 2025-06-30 have NULL `state_bottle_cost` and
`state_bottle_retail`, and no line after. The publisher's 2025 page says "Data not
available before 7/1/2025". `sales_dollars` is present on every line. 2026 has no NULLs.

<details><summary>Query</summary>

```sql
select substr(ordered_on, 1, 7) as month, count(*), count(*) filter (where state_bottle_cost is null)
from raw_iowa_data_hub.liquor_sales_2025 group by 1 order by 1;
```
</details>

### 5. `sales_dollars` ≠ bottles × retail on some lines

The publisher defines `sales_dollars` as bottles × `state_bottle_retail`. Outside #3 it
differs on 22,914 of 880,824 priced lines in 2025 (2.6%) and 22,446 of 1,846,769 in 2026
(1.2%). The gap is not on month boundaries, where a price change would show. It spreads over
every day of the month. Most ratios are near 1 (0.97, 0.99, 1.13, 1.15, 1.25):

| ordered_on | im_desc | retail | bottles | dollars | dollars / bottle |
|---|---|---|---|---|---|
| 2026-06-01 | EMPRESS 1908 GIN | 28.5 | 6 | 180 | 30.00 |
| 2026-06-01 | JAMESON | 53.22 | 12 | 584.64 | 48.72 |
| 2026-06-01 | ABSOLUT SWEDISH VODKA 80PRF | 22.49 | 2 | 38.98 | 19.49 |

Guess: discounts or price changes applied to the order but not to the line's list price.
Separately, retail is not 1.5 × cost on 119 (2025-07) and 102 (2025-08) lines, and on 16 lines in
2026 outside #3.

<details><summary>Query</summary>

```sql
select ordered_on, item_no, im_desc, state_bottle_retail, sales_bottles, sales_dollars,
       round(sales_dollars::numeric / nullif(sales_bottles::numeric, 0), 2) as per_bottle
from raw_iowa_data_hub.liquor_sales_2026
where ordered_on >= '2026-02-01'
  and abs(sales_dollars::numeric - sales_bottles::numeric * state_bottle_retail::numeric) > 0.01
limit 20;
```
</details>

### 6. Category names renamed; an item's category changes over time

On 2025-07-01, four names moved from plural to singular under the same code. 2026 has only
the new names, which match the current `liquor_products` names in upper case:

| category_code | Until 2025-06-30 | From 2025-07-01 |
|---|---|---|
| 1081300 | `AMERICAN CORDIALS & LIQUEURS` | `AMERICAN CORDIALS & LIQUEUR` |
| 1082100 | `IMPORTED CORDIALS & LIQUEURS` | `IMPORTED CORDIALS & LIQUEUR` |
| 1091100 | `AMERICAN DISTILLED SPIRITS SPECIALTY` | `AMERICAN DISTILLED SPIRIT SPECIALTY` |
| 1092100 | `IMPORTED DISTILLED SPIRITS SPECIALTY` | `IMPORTED DISTILLED SPIRIT SPECIALTY` |

The line carries the item's category at the time of sale. (`item_no`, `category_code`) has
135 (2025) and 35 (2026) more pairs than there are items. In the 2026 examples, items move in
and out of `TEMPORARY & SPECIALTY PACKAGES`, usually at the start of a month, e.g. 102754: `TEMPORARY & SPECIALTY PACKAGES` until
2026-07-31, `AMERICAN VODKAS` from 2026-08-03. `IOWA SPIRITS MANUFACTURERS`, the other
grouping in `liquor_products`, never appears on a sales line.

26 lines in 2026 have NULL category: all are item 921635 `TEMPLETON USA 250 STRAIGHT BOURBON
WHISKEY`, ordered 2026-06-15 – 2026-08-25.

<details><summary>Query</summary>

```sql
select category_code, category_name, count(*), min(ordered_on), max(ordered_on)
from raw_iowa_data_hub.liquor_sales_2025 group by 1, 2 order by 1, 2;

with s as (select item_no, category_code, category_name, count(*) as n,
                  min(ordered_on) as first_on, max(ordered_on) as last_on
           from raw_iowa_data_hub.liquor_sales_2026 group by 1, 2, 3)
select * from s
where item_no in (select item_no from s group by 1 having count(distinct category_code) > 1)
order by item_no, first_on;
```
</details>

### 7. Store attributes change over time; some locations missing

Per year, 2,243 (2025) and 2,237 (2026) stores carry 2,338 and 2,256 store names. Stores are
renamed when they change owner, e.g. 010038 `KUM & GO #1074 / WDM` until 2025-10-06, then
`MAVERIK #5364 / WDM`. Store 2619 also changes its address in Oct 2025.

The location columns (address, city, zip, FIPS, county) are NULL together on 2,065 (2025) and
2,582 (2026) lines. They belong to 8 and 6 stores. All but one store per year have the
location on other lines, e.g. 2619 has NULL from 2025-10-01 to 2025-10-08 only.

Store 2687 `HY-VEE FAST & FRESH EXPRESS- BETTENDORF` has zip `57222`, a South Dakota zip, on
286 (2025) and 183 (2026) lines. Bettendorf is 52722.

<details><summary>Query</summary>

```sql
with s as (select store_no, store_name, store_address, store_city, store_zip_code, county_name,
                  count(*) as n, min(ordered_on) as first_on, max(ordered_on) as last_on
           from raw_iowa_data_hub.liquor_sales_2025 group by 1, 2, 3, 4, 5, 6)
select * from s where store_no in (select store_no from s group by 1 having count(*) > 1)
order by store_no, first_on;

select store_no, store_name, store_city, store_zip_code, count(*)
from raw_iowa_data_hub.liquor_sales_2026 where store_zip_code !~ '^5[0-2]' group by 1, 2, 3, 4;
```
</details>

### 8. Item description and pack change over time

5,048 items carry 5,145 (`item_no`, `im_desc`) pairs in 2025, 4,792 carry 4,909 in 2026.
(`item_no`, `pack`, `bottle_volume_ml`) has 29 and 13 extra pairs. Examples from 2026:

| item_no | Before | After | From |
|---|---|---|---|
| 13038 | `CANADIAN RESERVE WHISKY` | `CANADIAN RESERVE WHISKY DISCO` | 2026-08-03 |
| 15606 | `GREEN SPOT` | `GREEN SPOT USE CODE 14820` | 2026-10-02 |
| 22249 | `WOODFORD RESERVE HOLIDAY 2025` | `WOODFORD RESERVE HOLIDAY 2026` | 2026-09-21 |
| 22151 | pack 10 | pack 12 | 2026-07-01 |

The status codes are the ones in `liquor_products` issue #10. 22249 shows one item number reused for
next year's edition. In Oct 2026, every line's description, vendor, pack, volume, cost, retail
and category match the current `liquor_products` row, so the latest lines agree with the catalog.

<details><summary>Query</summary>

```sql
with s as (select item_no, im_desc, pack, bottle_volume_ml, count(*) as n,
                  min(ordered_on) as first_on, max(ordered_on) as last_on
           from raw_iowa_data_hub.liquor_sales_2026 group by 1, 2, 3, 4)
select * from s where item_no in (select item_no from s group by 1 having count(*) > 1)
order by item_no, first_on;
```
</details>

### 9. Returns are `RINV-` lines with negative quantities

2,821 (2025) and 1,618 (2026) lines have `invoice_id` starting `RINV-`. All but 4 (2025) and
1 (2026) have negative bottles, dollars and liters. Another 4 (2025) and 2 (2026) `INV-`
lines are negative. Fewer lines have negative liters than negative bottles (2,549 vs 2,821
in 2025). Guess: returns of small bottles rounded to 0 liters in #3.

<details><summary>Query</summary>

```sql
select left(invoice_id, 4) as prefix, sign(sales_bottles::numeric) as sign, count(*)
from raw_iowa_data_hub.liquor_sales_2026 group by 1, 2 order by 1, 2;
```
</details>

### 10. `store_no` has two shapes

Older stores have 4 digits (2106–9049). Newer ones have 6 digits starting `010` (010003–010897).
Neither shape collides with the other as a number, but keep it as text like the publisher.

<details><summary>Query</summary>

```sql
select regexp_replace(store_no, '\d', '9', 'g') as shape, count(*), count(distinct store_no),
       min(store_no), max(store_no)
from raw_iowa_data_hub.liquor_sales_2026 tablesample system (5) repeatable (42) group by 1;
```
</details>

### 11. Double spaces in text

Sample rows with double spaces, 2025 / 2026: `vendor_name` 30,134 / 21,899, `store_address`
7,161 / 4,567, `store_name` 2,168 / 1,400, `im_desc` 155 / 53. No edge spaces. E.g.
`1725  74TH ST`, `ELIJAH  CRAIG TOASTED BARREL` (fixed to one space from 2026-03-02).

<details><summary>Query</summary>

```sql
select col, count(*) filter (where v <> btrim(v)) as edge_ws, count(*) filter (where v ~ '  ') as dbl_ws,
       count(*) filter (where v ~ '[^ -~]') as non_ascii
from raw_iowa_data_hub.liquor_sales_2026 tablesample system (5) repeatable (42),
     lateral (values ('store_name', store_name), ('store_address', store_address),
                     ('vendor_name', vendor_name), ('im_desc', im_desc)) t(col, v)
group by 1;
```
</details>
