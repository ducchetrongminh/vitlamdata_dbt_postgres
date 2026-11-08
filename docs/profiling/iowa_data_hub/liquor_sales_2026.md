# raw_iowa_data_hub.liquor_sales_2026

Profiled 2026-11-06, data as of 2026-11-06 18:00 +07. Checked again on the reload of
2026-11-07 00:03 +07, which the older years use: every full-scan result is unchanged. 2,029,764
rows, ordered 2026-01-01 – 2026-10-30, the same as the publisher's count. One row is one line
of a store's order from the state (an invoice line). The publisher says `invoice_id`
identifies the line, but it does not in 2026 (#1).

This is the reference profile for the sales years. Each older year's profile lists only
where it differs from this one.

Method: key, row counts, null counts, cast checks, ranges and cross-column checks are full
scans. Value distributions, shapes and text checks use a 5% sample,
`TABLESAMPLE SYSTEM (5) REPEATABLE (42)` (99,767 rows on the 18:00 load; the same sample
takes 100,485 rows after the reload, as it picks pages, not rows).

Publisher docs: the dataset page (data.iowa.gov dataset 1263) gives a column description for
each column, the source SQL (`SELECT * FROM iowa_data_hub_gold_prod.liquor_sales_combined
WHERE ordered_on` in 2026), `invoice_id` as the unique identifier and `ordered_on` as the
record date. The descriptions from `store_name` to `sales_bottles` are shifted by one column.

## Columns

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `invoice_id` | text | `INV-903316`, `INV-0990155`, `RINV-060442` | | invoice number only, not unique (#1). `RINV-` = returns (#7) |
| `ordered_on` | text → date | | 2026-01-01 – 2026-10-30 | all `YYYY-MM-DD`; Mon–Fri, plus 12 Saturdays and 16 Sundays |
| `store_no` | text | `2633`, `5444`, `010038` | | 2,237 stores; 4 digits or 6 digits starting `010`: keep as text (#8) |
| `store_name` | text | `HY-VEE #3 / BDI / DES MOINES`, `MAVERIK #5364 / WDM` | | 2,256 names; changes over time per store (#5) |
| `store_address` | text | `330 JORDAN CREEK PARKWAY`, `1725  74TH ST` | | 2,582 NULL (#5) |
| `store_city` | text | `WEST DES MOINES`, `MARSHALLTOWN` | | NULL with the address |
| `store_zip_code` | text | `50266`, `52337` | | always 5 digits; NULL with the address; one typo `57222` (#5) |
| `county_fips_code` | text | `19127`, `19153` | | 19001–19197: Iowa state code + county; NULL with the address |
| `county_name` | text | `POLK`, `MARSHALL` | | 99 counties, 1:1 with FIPS; NULL with the address |
| `category_code` | text | `1011200`, `1701100` | | 44 codes, 7 digits, one name each; 26 NULL (#4) |
| `category_name` | text | `STRAIGHT BOURBON WHISKIES`, `TEMPORARY & SPECIALTY PACKAGES` | | upper case; matches `liquor_products` names in upper case |
| `vendor_number` | text | `035`, `260` | | always 3 digits: keep as text (leading zeros); 207 vendors, one name each |
| `vendor_name` | text | `DIAGEO AMERICAS`, `BACARDI USA INC` | | double spaces (#9) |
| `item_no` | text | `38177`, `88296`, `102754` | | all digits, 3–6 long; 4,792 items; no orphans vs `liquor_products` |
| `im_desc` | text | `TITOS HANDMADE VODKA`, `GREEN SPOT USE CODE 14820` | | upper case; changes over time per item (#6) |
| `pack` | text → int | | 1 – 48 | changes over time for some items (#6) |
| `bottle_volume_ml` | text → int | | 20 – 4,500 | no zeros |
| `state_bottle_cost` | text → numeric | | 0 – 3,750 | whole numbers in Jan (#2); 42 zeros, all Jan |
| `state_bottle_retail` | text → numeric | | 1 – 5,625 | 1.5 × cost, except Jan (#2) and 16 lines |
| `sales_bottles` | text → int | | -192 – 13,200 | negatives are returns (#7) |
| `sales_dollars` | text → numeric | | -3,240 – 260,832 | ≠ bottles × retail on 1.2% of lines (#3) |
| `sales_liters` | text → numeric | | -120 – 13,200 | = bottles × volume / 1,000, except Jan (#2) |
| `sales_gallons` | text → numeric | | -31.70 – 3,487 | = bottles × volume / 3,785.41, except Jan (#2) |

- Nulls: none, except the store location columns (#5) and category on 26 lines (#4).
- Casts: clean. All 8 numeric columns match `^-?[0-9]+(\.[0-9]+)?$` and `ordered_on` matches
  `YYYY-MM-DD` on every row.
- The top lines are real. They are wholesale orders by the Hy-Vee distribution centre, store
  2633 `HY-VEE #3 / BDI / DES MOINES`, e.g. 13,200 bottles of Tito's for $260,832 on 2026-01-19.
- `sales_bottles` bins (sample): `<0` 83, 1–12 85,070, 13–48 12,334, 49–120 1,596,
  121–600 653, `>600` 31.
- Days: Mon–Fri carry 98.2% of lines. 12 Saturdays carry 29,447 lines and 16 Sundays 7,483.
  No future dates.
- `category_name`, `county_name`, `store_city` have no edge spaces, non-ASCII or lower case.
  `im_desc` has 17 non-ASCII rows in the sample.

## Issues

| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `invoice_id` | Invoice number only, not the line; no column set is unique | clean in staging: line key is a hash of all columns; whole-row repeats are dropped in intermediate (README Q8) | decided |
| 2 | cost, retail, dollars, liters, gallons | Rounded to whole numbers on lines ordered in Jan 2026 | accept: keep the rounded values; liters and gallons can be recomputed in staging (README Q10) | decided |
| 3 | `sales_dollars` | ≠ bottles × retail on 1.2% of lines outside #2 | accept: use `sales_dollars` as the amount. Most gaps are last month's price (README Q11) | decided |
| 4 | `category_code`, `category_name` | An item's category changes over time; 26 NULL | clean in staging: type 1, the item's latest category other than `TEMPORARY & SPECIALTY PACKAGES`; NULL → Unknown (README Q2, Q13, Q14) | decided |
| 5 | store columns | Name and address change over time; 2 stores carry two names at once; location NULL on 6 stores' lines; one zip typo | clean in staging: type 1, the latest line's name and location; a NULL location there stays Unknown (assumed cut out by the source system). zip `57222` → `52722` for store 2687 (README Q12, Q14) | decided |
| 6 | `im_desc`, `pack` | Item description and pack change over time, including status codes and reuse for a new edition | accept: the line keeps the values as sold. Decide history in the product dim | open |
| 7 | `invoice_id`, measures | Returns are `RINV-` lines with negative bottles and dollars; 1 `RINV-` line positive, 2 `INV-` lines negative | accept | open |
| 8 | `store_no` | Two shapes: 4 digits and 6 digits starting `010` | accept: keep as text | open |
| 9 | text | Double spaces in `vendor_name`, `store_address`, `store_name`, `im_desc` | clean in staging: squeeze spaces | open |

### 1. `invoice_id` is the invoice, not the line

`invoice_id` holds the invoice number alone, so 2,029,764 rows have 105,920 ids. From
2026-09-14 the number gains a leading zero (`INV-0990155`), which is cosmetic.

| Format | Ordered on | Rows | Distinct `invoice_id` |
|---|---|---|---|
| `INV-999999` | 2026-01-01 – 2026-09-14 | 1,687,224 | 86,235 |
| `INV-9999999` | 2026-09-14 – 2026-10-30 | 340,922 | 18,235 |
| `RINV-999999` | 2026-01-02 – 2026-10-30 | 1,618 | 1,450 |

(`invoice_id`, `item_no`) is not unique either: 2,027,248 pairs. An invoice can carry the
same item on several lines, e.g. a full case plus loose bottles:

| invoice_id | item_no | im_desc | sales_bottles | sales_dollars |
|---|---|---|---|---|
| INV-0997227 | 17956 | EVAN WILLIAMS BLACK | 12 | 171 |
| INV-0997227 | 17956 | EVAN WILLIAMS BLACK | 1 | 14.25 |

Even the whole row is not unique: 14 rows repeat another row in every column. The table
matches the publisher's row count, so they are likely real repeated lines (guess). There is
no natural line key.

<details><summary>Query</summary>

```sql
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

### 2. Money and volume are whole numbers in Jan 2026

On lines ordered in Jan 2026, cost, retail, dollars, liters and gallons are whole numbers
(2 of 182,995 lines keep decimals). Each is rounded on its own, so they no longer agree.
From Feb, liters and gallons equal bottles × volume on every line.

| invoice_id | ordered_on | im_desc | bottles | ml | cost | retail | dollars | liters | gallons |
|---|---|---|---|---|---|---|---|---|---|
| INV-903882 | 2026-01-05 | HAWKEYE VODKA MINI | 12 | 50 | 4 | 6 | 81 | 0 | 0 |
| INV-904288 | 2026-01-05 | HAWKEYE VODKA MINI | 2 | 50 | 4 | 6 | 13 | 0 | 0 |

12 × 6 = 72, not 81, so the real retail was about 6.75. The 0.6 l of minis shows as 0 liters.
This rounding is the source of all 42 zero `state_bottle_cost` lines and 42,208 zero-liter lines.

| Month | Lines | Liters ≠ bottles × ml / 1000 | Gallons off | Dollars ≠ bottles × retail | Retail ≠ 1.5 × cost |
|---|---|---|---|---|---|
| 2026-01 | 182,995 | 120,240 | 182,871 | 120,224 | 114,529 |
| 2026-02 | 174,168 | 0 | 0 | 945 | 0 |
| 2026-03 – 2026-10 | 1,672,601 | 0 | 0 | 21,501 | 16 |

Liters and gallons can be recomputed in staging from `sales_bottles` and `bottle_volume_ml`.
Cost, retail and dollars cannot be recovered from this table.

<details><summary>Query</summary>

```sql
select substr(ordered_on, 1, 7) as month, count(*) as lines,
       count(*) filter (where abs(sales_liters::numeric
                        - sales_bottles::numeric * bottle_volume_ml::numeric / 1000) > 0.01) as liters_off,
       count(*) filter (where abs(sales_gallons::numeric
                        - sales_bottles::numeric * bottle_volume_ml::numeric / 3785.41) > 0.01) as gallons_off,
       count(*) filter (where abs(sales_dollars::numeric
                        - sales_bottles::numeric * state_bottle_retail::numeric) > 0.01) as dollars_off,
       count(*) filter (where abs(state_bottle_retail::numeric
                        - round(state_bottle_cost::numeric * 1.5, 2)) > 0.01) as retail_not_15x,
       count(*) filter (where (state_bottle_cost || state_bottle_retail || sales_dollars || sales_gallons) ~ '\.') as has_decimals,
       count(*) filter (where state_bottle_cost::numeric = 0) as zero_cost,
       count(*) filter (where sales_liters::numeric = 0) as zero_liters
from raw_iowa_data_hub.liquor_sales_2026 group by 1 order by 1;
```
</details>

### 3. `sales_dollars` ≠ bottles × retail on some lines

The publisher defines `sales_dollars` as bottles × `state_bottle_retail`. Outside #2 it
differs on 22,446 of 1,846,769 lines (1.2%), 974 to 5,699 a month. The gap is not on month
boundaries, where a price change would show. It spreads over every day of the month. Most
ratios are near 1 (0.97, 0.99, 1.13, 1.15, 1.25):

| ordered_on | im_desc | retail | bottles | dollars | dollars / bottle |
|---|---|---|---|---|---|
| 2026-06-01 | EMPRESS 1908 GIN | 28.5 | 1 | 30 | 30.00 |
| 2026-06-01 | JAMESON | 53.22 | 6 | 292.32 | 48.72 |
| 2026-06-01 | ABSOLUT SWEDISH VODKA 80PRF | 22.49 | 12 | 233.88 | 19.49 |

20,649 of the 22,446 lines (92%) are billed at the item's retail of the previous month. All
of them are items whose retail changed that month. About 1 in 9 lines of such an item still
gets the old price, on any day of the month. Guess: some orders keep the price in force when
they were placed. So `sales_dollars` is the amount billed and `state_bottle_retail` the
current list price (README Q11).
Separately, retail is not 1.5 × cost on 16 lines outside #2.

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

### 4. An item's category changes over time; 26 lines have none

The line carries the item's category at the time of sale. 4,792 items carry 4,827
(`item_no`, `category_code`) pairs. Items move in and out of `TEMPORARY & SPECIALTY
PACKAGES`, usually at the start of a month:

| item_no | im_desc | category_name | Ordered on |
|---|---|---|---|
| 102754 | SVEDKA VODKA MINI | TEMPORARY & SPECIALTY PACKAGES | 2026-01-02 – 2026-07-31 |
| 102754 | SVEDKA VODKA MINI | AMERICAN VODKAS | 2026-08-03 – 2026-10-07 |

`IOWA SPIRITS MANUFACTURERS`, the other grouping in `liquor_products`, never appears on a
sales line. Each of the 44 codes has one name all year.

26 lines have NULL category: all are item 921635 `TEMPLETON USA 250 STRAIGHT BOURBON
WHISKEY`, ordered 2026-06-15 – 2026-08-25.

<details><summary>Query</summary>

```sql
select category_code, category_name, count(*), min(ordered_on), max(ordered_on)
from raw_iowa_data_hub.liquor_sales_2026 group by 1, 2 order by 1, 2;

with s as (select item_no, category_code, category_name, count(*) as n,
                  min(ordered_on) as first_on, max(ordered_on) as last_on
           from raw_iowa_data_hub.liquor_sales_2026 group by 1, 2, 3)
select * from s
where item_no in (select item_no from s group by 1 having count(distinct category_code) > 1)
order by item_no, first_on;
```
</details>

### 5. Store attributes change over time; some locations missing

2,237 stores carry 2,256 store names. Most changes add a city suffix or follow a change of
owner. Two stores carry two names on the same days, in different towns. Guess: one name's
lines were keyed to the wrong store number.

| store_no | store_name | Lines | Ordered on |
|---|---|---|---|
| 010764 | `HOPSTOP LIQUOR AND GROCERIES` | 351 | 2026-02-26 |
| 010764 | `HOPSTOP LIQUOR AND GROCERIES / WEBSTER CITY` | 825 | 2026-03-11 – 2026-10-29 |
| 010821 | `WORLD LIQUOR & TOBACCO + VAPORS` | 117 | 2026-05-13 |
| 010821 | `GK BOONE LLC / BOONE` | 707 | 2026-05-22 – 2026-10-27 |
| 010830 | `VENTURA TOWN MART / VENTURA` | 108 | 2026-06-25 – 2026-10-29 |
| 010830 | `GARNER TOWN MART / GARNER` | 8 | 2026-09-17 |
| 010860 | `PUMP & PANTRY 70 / JOHNSTON` | 102 | 2026-08-02 – 2026-10-29 |
| 010860 | `HY-VEE GAS / JOHNSTON` | 36 | 2026-08-03 – 2026-08-12 |

The location columns (address, city, zip, FIPS, county) are NULL together on 2,582 lines of 6
stores. Five have the location on their other lines. Store 010206 has no location on any of
its 928 lines.

| store_no | Lines | NULL lines | NULL from – to |
|---|---|---|---|
| 010003 | 1,837 | 216 | 2026-08-04 – 2026-08-18 |
| 010206 | 928 | 928 | 2026-01-07 – 2026-10-28 |
| 2501 | 5,789 | 277 | 2026-08-05 – 2026-08-13 |
| 4427 | 502 | 21 | 2026-01-06 |
| 4829 | 15,765 | 1,108 | 2026-08-03 – 2026-08-24 |
| 4993 | 554 | 32 | 2026-10-07 |

Store 2687 `HY-VEE FAST & FRESH EXPRESS- BETTENDORF` has zip `57222`, a South Dakota zip, on
183 lines. Bettendorf is 52722.

<details><summary>Query</summary>

```sql
with s as (select store_no, store_name, store_address, store_city, store_zip_code, county_name,
                  count(*) as n, min(ordered_on) as first_on, max(ordered_on) as last_on
           from raw_iowa_data_hub.liquor_sales_2026 group by 1, 2, 3, 4, 5, 6)
select * from s where store_no in (select store_no from s group by 1 having count(*) > 1)
order by store_no, first_on;

select store_no, store_name, store_city, store_zip_code, count(*)
from raw_iowa_data_hub.liquor_sales_2026 where store_zip_code !~ '^5[0-2]' group by 1, 2, 3, 4;
```
</details>

### 6. Item description and pack change over time

4,792 items carry 4,909 (`item_no`, `im_desc`) pairs. (`item_no`, `pack`,
`bottle_volume_ml`) has 13 extra pairs. Examples:

| item_no | Before | After | From |
|---|---|---|---|
| 13038 | `CANADIAN RESERVE WHISKY` | `CANADIAN RESERVE WHISKY DISCO` | 2026-08-03 |
| 15606 | `GREEN SPOT` | `GREEN SPOT USE CODE 14820` | 2026-10-02 |
| 22249 | `WOODFORD RESERVE HOLIDAY 2025` | `WOODFORD RESERVE HOLIDAY 2026` | 2026-09-21 |
| 22151 | pack 10 | pack 12 | 2026-07-01 |

The status codes are the ones in `liquor_products` issue #10. 22249 shows one item number
reused for next year's edition. In Oct 2026, every line's description, vendor, pack, volume,
cost, retail and category match the current `liquor_products` row, so the latest lines agree
with the catalog.

<details><summary>Query</summary>

```sql
with s as (select item_no, im_desc, pack, bottle_volume_ml, count(*) as n,
                  min(ordered_on) as first_on, max(ordered_on) as last_on
           from raw_iowa_data_hub.liquor_sales_2026 group by 1, 2, 3, 4)
select * from s where item_no in (select item_no from s group by 1 having count(*) > 1)
order by item_no, first_on;
```
</details>

### 7. Returns are `RINV-` lines with negative quantities

1,618 lines have `invoice_id` starting `RINV-`. All but 1 have negative bottles and dollars.
Another 2 `INV-` lines are negative.

| Prefix | Sign | Lines |
|---|---|---|
| `INV-` | + | 2,028,144 |
| `INV-` | − | 2 |
| `RINV-` | − | 1,617 |
| `RINV-` | + | 1 |

<details><summary>Query</summary>

```sql
select left(invoice_id, 4) as prefix, sign(sales_bottles::numeric) as bottles,
       sign(sales_dollars::numeric) as dollars, count(*)
from raw_iowa_data_hub.liquor_sales_2026 group by 1, 2, 3 order by 1, 2, 3;
```
</details>

### 8. `store_no` has two shapes

Older stores have 4 digits (1,615 stores, 2130–9052). Newer ones have 6 digits starting `010`
(622 stores, 010003–010903). Neither shape collides with the other as a number, but keep it
as text like the publisher.

<details><summary>Query</summary>

```sql
select regexp_replace(store_no, '\d', '9', 'g') as shape, count(*), count(distinct store_no),
       min(store_no), max(store_no)
from raw_iowa_data_hub.liquor_sales_2026 group by 1;
```
</details>

### 9. Double spaces in text

Sample rows with double spaces: `vendor_name` 22,446, `store_address` 4,070, `store_name`
1,248, `im_desc` 79. No edge spaces. E.g. `1725  74TH ST`, `ELIJAH  CRAIG TOASTED BARREL`
(fixed to one space from 2026-03-02).

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
