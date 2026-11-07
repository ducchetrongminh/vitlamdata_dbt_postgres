# raw_iowa_data_hub.liquor_sales_2018

Profiled 2026-11-07, data as of 2026-11-07 00:03 +07. 2,355,558 rows, ordered
2018-01-02 – 2018-12-31. No row repeats another. One row is one invoice line, as in 2026.

Same as [2019](liquor_sales_2019.md), and through it the later years, except where listed
below. Same method and checks. The 5% sample has 115,777 rows.

## Columns

Only the columns that differ from 2019.

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `ordered_on` | text → date | | 2018-01-02 – 2018-12-31 | no Sunday; 1 Saturday (5,290 rows) |
| `store_no` | text | `9936` | | 1,637 stores, 4 digits (2106–9938) |
| `store_name` | text | `"DOUBLE ""D"" LIQUOR STORE"` | | 1,668 names. One name keeps the CSV's quotes (2026 #5) |
| `store_zip_code`, `county_fips_code`, `county_name` | text | `80904`, `EL PASO` | | one store outside Iowa (#3); no zip `57222` (store 2687 not open yet) |
| `category_code`, `category_name` | text | `1091400 IOWA DISTILLERIES` | | 53 codes; NULL on 2,021 lines (2026 #4) |
| `vendor_number`, `vendor_name` | text | `010` | | 186 vendors, 188 names; NULL on 2 lines (2021 #1) |
| `item_no` | text | | | 3,954 items; 1,331 not in `liquor_products` (2022 #2) |
| `bottle_volume_ml` | text → int | | 20 – 6,000 | 42 minis switch to the pack total on 2018-10-01 (#1) |
| `sales_bottles` | text → int | | 0 – 11,952 | one line with 0 bottles (#2) |
| `sales_dollars` | text → numeric | | 0 – 279,557.28 | 500 lines with $0 (#2) |
| `sales_liters` | text → numeric | | 0.02 – 8,964 | |
| `sales_gallons` | text → numeric | | 0 – 2,368.03 | |

- Top lines: Hy-Vee Urbandale (2663) ordered 11,952 bottles of Crown Royal for $279,557.28
  on 2018-10-02, the largest amount in any year profiled so far.
- `sales_bottles` bins (sample): 1–12 102,478, 13–48 11,175, 49–120 1,405, 121–600 682,
  `>600` 37.

## Issues

| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `bottle_volume_ml` | 42 minis switch from a bottle's ml to the pack's total on 2018-10-01; 2019 #1 switches them back | clean in staging: type 1, the latest volume; recompute liters (README Q15) | decided |
| 2 | `sales_dollars`, `sales_bottles` | 500 lines with bottles but $0, Jan–Jul; 1 line with $359.64 but 0 bottles | accept: keep as is (README Q18) | decided |
| 3 | store columns | Store 9936 `DASH EVENTS LLC` is in Colorado Springs, county `EL PASO`, no FIPS: 2 lines | accept: keep, flag as out of state | open |
| 2019 #1 | `bottle_volume_ml` | Pack total for the 2025 #2 items all year, e.g. 48102 at 1,200 | as 2019 #1 | open |
| 2021 #1 | `vendor_number` | NULL on 2 lines: `INV-13688900001` item 973449, `INV-12438800004` item 910621 | as 2021 #1 | open |
| 2022 #1 | category, returns, stores | Old system all year. `1091400 IOWA DISTILLERIES` appears only here, 1,071 lines Jan–Sep | as 2022 #1 | open |
| 2022 #2 | `item_no` | 1,331 items, 86,439 lines (3.7%), not in the catalog, e.g. 40052 `DEEP EDDY LEMON MINI` (1,203) | as 2022 #2 | open |
| 2025 #3 | cost, retail | NULL all year | as 2025 #3 | open |
| 2025 #4 | `invoice_id` | Invoice + line, unique on all 2,355,558 lines | as 2025 #4 | open |
| 2025 #6 | `vendor_name` | 192 spelled `MAST-JAEGERMEISTER` on 3 lines, `MAST-JAGERMEISTER` otherwise | as 2025 #6 | open |
| 2026 #4 | category | NULL on 2,021 lines, all year, e.g. 80024 `BLUE CHAIR BAY BANANA RUM CREAM` (304) | as 2026 #4 | open |
| 2026 #5 | store columns | Location NULL on 1,693 lines of 7 stores. 4777 has none on 248 of its 362 lines | as 2026 #5 | open |
| 2026 #6 | `im_desc`, `pack` | 4,410 (`item_no`, `im_desc`) pairs for 3,954 items; 49 items change pack or volume, 42 of them #1 | as 2026 #6 | open |
| 2026 #9 | text | Double spaces (sample): `vendor_name` 8,399, `store_address` 9,877, `store_name` 2,725, `im_desc` 3 | as 2026 #9 | open |

### 1. 42 minis switch to the pack's volume on 2018-10-01

In Oct 2018, 42 items change `bottle_volume_ml` to a larger value that the old one divides.
A bottle's volume becomes the pack's total. Most are minis:

| item_no | im_desc | pack | ml until Sep 2018 | ml from Oct 2018 |
|---|---|---|---|---|
| 34818 | SVEDKA VODKA MINI | 10 | 50 | 600 |
| 36265 | GRAYS PEAK VODKA MINI | 12 | 50 | 500 |
| 29420 | BLUE OX GIN MINI | 1 | 50 | 3,000 |

The ratio does not always match `pack` (Svedka: 10 a pack, 12 × 50 ml), and Blue Ox at pack 1
holds 3,000 ml. On 2019-08-01 most such items go back to a bottle's volume (2019 #1). So
liters for minis from Oct 2018 to Jul 2019 are inflated by the bottles per unit.

<details><summary>Query</summary>

```sql
with s as (select item_no, bottle_volume_ml::int as v, min(ordered_on) as first_on,
                  max(ordered_on) as last_on
           from raw_iowa_data_hub.liquor_sales_2018 group by 1, 2),
     c as (select a.item_no, a.v as old_v, b.v as new_v, b.first_on
           from s a join s b on a.item_no = b.item_no and a.last_on < b.first_on and a.v <> b.v)
select substr(first_on, 1, 7) as month, count(*) as changes,
       count(*) filter (where new_v > old_v and new_v % old_v = 0) as to_pack
from c group by 1 order by 1;
```
</details>

### 2. Lines with bottles but no dollars

From Jan to Jul 2018, 60–81 lines a month have bottles but `sales_dollars` = 0: 500 in all,
on about 70 items and 60 stores a month. 459 of them are line 1 of their invoice, often the only line. None after Jul.

| invoice_id | ordered_on | store_name | im_desc | bottles | dollars |
|---|---|---|---|---|---|
| INV-09573100001 | 2018-01-03 | HILLSTREET NEWS AND TOBACCO | JIM BEAM | 3 | 0 |
| INV-09584900001 | 2018-01-03 | CASEY'S GENERAL STORE #2237 / PRAIRIE CITY | KAHLUA COFFEE LIQUEUR | 1 | 0 |

The reverse also occurs once: `INV-12453700001`, store 9911 `SOUTHERN GLAZERS WINE & SPIRITS
OF IOWA`, 0 bottles of Glenlivet for $359.64. Guess: free goods or samples, and a
price-only adjustment.

<details><summary>Query</summary>

```sql
select substr(ordered_on, 1, 7) as month, count(*), count(distinct item_no), count(distinct store_no)
from raw_iowa_data_hub.liquor_sales_2018
where sales_dollars::numeric = 0 or sales_bottles::int = 0 group by 1 order by 1;
```
</details>

### 3. A store outside Iowa

Store 9936 `DASH EVENTS LLC`, `1685 W UINTAH ST. #101`, `COLORADO SPRINGS`, zip 80904, county
`EL PASO`, has 2 lines on 2018-01-18. Its FIPS code is NULL, as Iowa codes cannot hold it.
Every other store in every year so far is in Iowa.

<details><summary>Query</summary>

```sql
select * from raw_iowa_data_hub.liquor_sales_2018 where store_no = '9936';
```
</details>
