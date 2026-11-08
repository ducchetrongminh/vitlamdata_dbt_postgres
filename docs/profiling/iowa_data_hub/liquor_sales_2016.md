# raw_iowa_data_hub.liquor_sales_2016

Profiled 2026-11-07, data as of 2026-11-07 00:03 +07. 2,279,893 rows, ordered
2016-01-04 – 2016-12-30. No row repeats another. One row is one invoice line, as in 2026.

Same as [2017](liquor_sales_2017.md), and through it the later years, except where listed
below. Same method and checks. The 5% sample has 111,608 rows. From 2016-08-29 the year looks
like 2017. Before, several columns follow an older system (#1).

## Columns

Only the columns that differ from 2017.

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `invoice_id` | text | `S31923800002`, `INV-00753500014` | | `S` + 11 digits until 2016-08-26, `INV-` from 2016-08-29 (#1). Unique |
| `ordered_on` | text → date | | 2016-01-04 – 2016-12-30 | no Sunday; 2 Saturdays (8,258 rows) |
| `store_no` | text | | | 1,462 stores, 4 digits (2106–9930) |
| `store_name` | text | `KEYSTONE LIQUOR AND WINE / CORALVILL` | | 1,576 names (2026 #5) |
| `store_zip_code` | text | `712-2` | | `712-2` on 1,336 lines of store 4307 (#3) |
| `county_fips_code`, `county_name` | text | | | NULL on 98,229 lines: 68,371 have an address (#4) |
| `category_code`, `category_name` | text | `1031080 VODKA 80 PROOF` | | 100 codes, 135 code-name pairs: an older taxonomy until 2016-08-26 (#1). NULL code on 6,388 lines; NULL name with a code on 5,750 |
| `vendor_number` | text | `10`, `079` | | 2 digits, without the leading zero, on 319,727 lines before 2016-08-29 (#1). NULL on 2 lines (2021 #1) |
| `vendor_name` | text | `R�MY COINTREAU USA` | | 168 vendors, 243 names (#1); broken character (#2) |
| `item_no` | text | `x904631` | | 3,724 items; `x904631` on 1 line (2017 #1); 1,606 not in `liquor_products` (2022 #2) |
| `pack` | text → int | | 1 – 336 | Sam's Club tray packs of 288–336 × 1.75 L |
| `bottle_volume_ml` | text → int | | 50 – 378,000 | bulk buys sold as one unit (#5) |
| `sales_bottles` | text → int | | 0 – 6,600 | 6 lines with 0 bottles (2018 #2) |
| `sales_dollars` | text → numeric | | 0 – 181,962 | 526 lines with $0, all from 2016-08-29 (2018 #2) |

- Top lines: Hy-Vee 2633 ordered 6,600 bottles of Jack Daniel's for $181,962 on 2016-04-25.
- Fridays carry far fewer lines (151,812 on 41 days) than other weekdays.
- `sales_bottles` bins (sample): 1–12 100,083, 13–48 9,853, 49–120 1,212, 121–600 432,
  `>600` 28.

## Issues

| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `invoice_id`, category, vendor | A system change on 2016-08-29: invoice format, category taxonomy, vendor number format and vendor names all change | clean in staging: type 1, the item takes its latest category, else the legacy category map; keep the old name as legacy category (README Q19, Q21); keep both vendor codes (10 and 010); the old code takes the later code's name as current vendor name, type 3 | open |
| 2 | `vendor_name` | `R�MY COINTREAU USA`: the `É` is a replacement character on 5,749 lines | clean in staging: replace with `É` | open |
| 3 | `store_zip_code` | `712-2` on 1,336 lines of store 4307 (Dunlap) | clean in staging: take the zip from the store's other years | open |
| 4 | `county_fips_code`, `county_name` | NULL on 68,371 lines that have an address, all before 2016-08-29 | clean in staging: take the county from the store's other lines | open |
| 5 | `bottle_volume_ml` | Bulk buys sold as one unit: 378,000 ml (`18 CASES SMIRNOFF 1.75L/18 CASES CAPTAIN 1.75L`), 225,000 and 189,000 ml (Cedar Ridge whole casks) | accept: liters stay right; bottles count units, not bottles | open |
| 2017 #2 | store location | NULL on 29,858 lines of about 60 stores, all from Sep 2016 | as 2017 #2 | open |
| 2018 #2 | `sales_dollars` | 526 lines with bottles but $0, and 6 with $ but 0 bottles, all from 2016-08-29 | as 2018 #2 | open |
| 2021 #1 | `vendor_number` | NULL on 2 lines, both `RESERVOIR DISTILLERY` (2016-10-17) | as 2021 #1 | open |
| 2022 #1 | category, returns, stores | No returns, 4-digit stores | as 2022 #1 | open |
| 2022 #2 | `item_no` | 1,606 items, 127,120 lines (5.6%), not in the catalog | as 2022 #2 | open |
| 2025 #2 | `bottle_volume_ml` | Pack total for the 2025 #2 items, e.g. 48102 at 1,200 | as 2025 #2 | open |
| 2025 #3 | cost, retail | NULL all year | as 2025 #3 | open |
| 2025 #4 | `invoice_id` | Unique on all 2,279,893 lines, in both formats | as 2025 #4 | open |
| 2026 #4 | category | NULL code on 6,388 lines, 6,381 of them after 2016-08-29, of 202 items, e.g. 10549 `BLACK VELVET TOASTED CARAMEL MINI DISCO` | as 2026 #4 | open |
| 2026 #9 | text | Double spaces also in `category_name` (`MISCELLANEOUS  BRANDIES`) | as 2026 #9 | open |

### 1. A system change on 2016-08-29

The last line in the old format is ordered 2016-08-26, the first in the new on 2016-08-29.
Four things change at once.

`invoice_id`: `S31923800002` (S + 11 digits) before, `INV-00016600079` after. Both are the
invoice plus a line number and unique.

Category: before, an older and finer taxonomy, e.g. `1031080 VODKA 80 PROOF`, `1081305 APPLE
SCHNAPPS`, `1062200 PUERTO RICO & VIRGIN ISLANDS RUM`. After, the taxonomy of later years.
Some codes are reused with another meaning, so a code alone does not identify a category:

| category_code | Until 2016-08-26 | From 2016-08-29 |
|---|---|---|
| 1011300 | TENNESSEE WHISKIES | SINGLE BARREL BOURBON WHISKIES |
| 1012300 | IRISH WHISKIES | SINGLE MALT SCOTCH |
| 1022100 | TEQUILA | MIXTO TEQUILA |
| 1062200 | PUERTO RICO & VIRGIN ISLANDS RUM | WHITE RUM |
| 1081300 | PEPPERMINT SCHNAPPS | AMERICAN CORDIALS & LIQUEURS |

Before the change, 5,750 lines carry a code of the new taxonomy with no name, e.g. 1022200
(later `100% AGAVE TEQUILA`).

Vendor number: before, vendors under 100 have no leading zero on 319,727 lines (`10`, not
`010`). Vendor name: many are spelled differently before and after, e.g. 115 `CONSTELLATION
WINE COMPANY, INC.` → `CONSTELLATION BRANDS INC`, so 168 vendors carry 243 names.

<details><summary>Query</summary>

```sql
select category_code, category_name, count(*), min(ordered_on), max(ordered_on)
from raw_iowa_data_hub.liquor_sales_2016 group by 1, 2 order by 1, 4;

select ordered_on < '2016-08-29' as before, left(invoice_id, 1) as invoice_prefix,
       length(vendor_number) as vendor_len, count(*)
from raw_iowa_data_hub.liquor_sales_2016 group by 1, 2, 3 order by 1, 2, 3;
```
</details>

### 2. A broken character in a vendor name

Vendor 389 is `R�MY COINTREAU USA` on 5,749 lines: the `É` of `RÉMY` was lost in an encoding
step before the export, and is now the replacement character U+FFFD.

<details><summary>Query</summary>

```sql
select vendor_number, vendor_name, count(*) from raw_iowa_data_hub.liquor_sales_2016
where vendor_name ~ '[^ -~]' group by 1, 2;
```
</details>

### 3. Zip `712-2`

Store 4307 `CROSSROADS WINE AND LIQUOR`, Dunlap, has zip `712-2` on 1,336 lines (865 of them
also lack the county). Dunlap's zip is 51529. Guess: the start of a phone number (area code 712).

<details><summary>Query</summary>

```sql
select store_no, store_name, store_city, store_zip_code, county_name, count(*)
from raw_iowa_data_hub.liquor_sales_2016 where store_zip_code !~ '^\d{5}$' group by 1, 2, 3, 4, 5;
```
</details>

### 4. County missing where the address is present

Before 2016-08-29, 68,371 lines have an address, city and zip but no FIPS code or county,
e.g. 3820 `CHARLIE'S WINE AND SPIRITS,` Sioux City (3,737 lines), 3632 `WAL-MART 2004 /
DUBUQUE` (1,441). After the change, no line has an address without a county.

<details><summary>Query</summary>

```sql
select store_no, store_name, store_city, store_zip_code, count(*)
from raw_iowa_data_hub.liquor_sales_2016
where county_fips_code is null and store_address is not null
group by 1, 2, 3, 4 order by 5 desc;
```
</details>

### 5. Bulk buys sold as one unit

A few lines sell a whole cask or a pallet as one bottle:

| item_no | im_desc | pack | bottle_volume_ml | Lines |
|---|---|---|---|---|
| 989491 | 18 CASES SMIRNOFF 1.75L/18 CASES CAPTAIN 1.75L | 1 | 378,000 | 24 |
| 946127 | CEDAR RIDGE BARREL AGED RUM 5YR RESERVE | 1 | 225,000 | 1 |
| 927011 | CEDAR RIDGE RYE WHISKEY - WHOLE CASK BUY | 1 | 189,000 | 2 |

Liters are right for these lines, since they follow the volume. Bottles count the units.

<details><summary>Query</summary>

```sql
select item_no, im_desc, pack, bottle_volume_ml, count(*), min(ordered_on), max(ordered_on)
from raw_iowa_data_hub.liquor_sales_2016 where bottle_volume_ml::int > 6000 group by 1, 2, 3, 4;
```
</details>
