# raw_iowa_liquor.products

Profiled 2026-11-05, load `1793883467.6571584`. 14,040 rows, 11,668 items. One row is
an item in one category: (`item_no`, `category_name`) is unique; `item_no` alone is not.
`report_as_of` is `2026-11-01` on every row.

Checks that found nothing:
- Nulls: none in any column except `scc` (3,559 rows).
- Casts: clean. All code and integer columns are digits only, all three price columns
  are numbers with at most 2 decimals, `list_on` and `report_as_of` are all
  `YYYY-MM-DD`. No negatives.
- Within an item, every column except `category_name` is identical across its rows.
- `vendor_no` ↔ `vendor_name` is 1:1 (393 vendors).

## Columns

| Column | Cast to | Note |
|---|---|---|
| `item_no` | text | Product code, 3–7 digits, no leading zeros. Not unique alone (#1). Keep text to match `sales_*.item_no`. |
| `category_name` | text | 48 values. Near-duplicates (#2). Items listed in 2–3 categories (#1). Sales spells it in upper case. |
| `im_desc` | text | Product description. Carries markers: "DISCO", "USE CODE nnnnnn", prefixes "HA", "BP", "CM", "Ingredient" (README question 3). 44 items have double spaces, 2 trailing spaces. Not unique: 9,922 values for 11,668 items. |
| `vendor_no` | text | 3 digits, zero-padded (`035`). Keep text. |
| `vendor_name` | text | One vendor has a double space ("SAZERAC COMPANY  INC"). |
| `bottle_volume_ml` | integer | 0 for 14 non-bottle items (#4). 750 is 68% of rows. |
| `pack` | integer | Bottles per case, 1–120. |
| `inner_pack` | integer | 1–300. Guess: units per inner carton (mini packs show 10, 12, 60, 120). |
| `age` | integer | 0 for 85% of rows. Mixes years and months (#3). |
| `proof` | integer | 0 for 15 rows (#4). Otherwise 9–190. |
| `list_on` | date | Always day 1 since 2020-11; 376 older items carry a real day. 110 rows in the future (#7). |
| `upc` | text | 12 digits, leading zeros (6,788 rows). Not a product key (#6). |
| `scc` | text | Case code, 13–14 digits. Mostly placeholders (#5). |
| `state_bottle_cost` | numeric(10,2) | Price outliers (#9). |
| `state_case_cost` | numeric(10,2) | Not always bottle cost × pack (#8). |
| `state_bottle_retail` | numeric(10,2) | 1.5 × bottle cost for 14,008 of 14,040 rows (#9). |
| `report_as_of` | date | Snapshot date, one value per load. |

## Issues

| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `item_no`, `category_name` | 2,354 items have 2–3 rows, one per category; the extra category is a tag | ask | open |
| 2 | `category_name` | Singular/plural near-duplicates | clean in staging: map `American Cordials & Liqueurs` → `American Cordials & Liqueur`, `Imported Cordials & Liqueurs` → `Imported Cordials & Liqueur`, `Imported Vodka` → `Imported Vodkas` | open |
| 3 | `age` | Mixes years and months; 0 means unknown or unaged | ask; meanwhile clean in staging: `nullif(age, 0)` | open |
| 4 | `bottle_volume_ml`, `proof` | 0 on non-bottle items (bulk "Ingredient" spirits, a magazine) and on one real whisky | clean in staging: `nullif(…, 0)` | open |
| 5 | `scc` | 8 placeholder codes cover 8,775 items | accept: do not use as a key | open |
| 6 | `upc` | Shared by unrelated items; not a product key | accept: do not use as a key | open |
| 7 | `list_on` | 110 rows listed after the report date | ask | open |
| 8 | `state_case_cost` | ≠ bottle cost × pack for 145 items, 30 by more than 2% | ask; meanwhile accept raw, do not derive one from the other | open |
| 9 | `state_bottle_cost` | Off the 1.5 markup for 13 items; one cost looks like a typo | ask; meanwhile accept | open |

### 1. Items listed in 2–3 categories

2,336 items have 2 rows and 18 have 3; the rows differ only in `category_name`. 1,733
of the 1,737 "Temporary & Specialty Packages" rows and all 631 "Iowa Spirits
Manufacturers" rows belong to such items. In `sales_2026`, every one of the 840
multi-category items that sold uses its other (base) category. Guess: these two are
tags (gift pack, made in Iowa), not categories.

| cats | items |
|---|---|
| Straight Bourbon Whiskies + Temporary & Specialty Packages | 357 |
| 100% Agave Tequila + Temporary & Specialty Packages | 163 |
| Blended Whiskies + Temporary & Specialty Packages | 108 |
| American Vodkas + Iowa Spirits Manufacturers | 83 |
| Temporary & Specialty Packages + Iowa Spirits Manufacturers + Straight Bourbon Whiskies | (one of 18 triples) |

Option for staging, pending the answer: one row per item with the base category plus
`is_temporary_specialty_package` and `is_iowa_spirits_manufacturer` flags. 4 items are
only in "Temporary & Specialty Packages" and would have no base category.

<details><summary>Query</summary>

```sql
with m as (
    select item_no, string_agg(category_name, ' + ' order by category_name) as cats
    from raw_iowa_liquor.products
    group by 1
    having count(*) > 1
)
select cats, count(*) as items
from m
group by 1
order by 2 desc;
```
</details>

### 2. `category_name` singular/plural near-duplicates

Three rare spellings sit next to a common one. Sales uses the common spelling
(`AMERICAN CORDIALS & LIQUEUR` code 1081300, `IMPORTED VODKAS` code 1032100).

| category_name | rows |
|---|---|
| American Cordials & Liqueur | 381 |
| American Cordials & Liqueurs | 3 |
| Imported Cordials & Liqueur | 471 |
| Imported Cordials & Liqueurs | 3 |
| Imported Vodka | 5 |
| Imported Vodkas | 202 |

<details><summary>Query</summary>

```sql
select category_name, count(*)
from raw_iowa_liquor.products
where category_name ~ '^(American|Imported) (Cordials|Vodka)'
group by 1
order by 1;
```
</details>

### 3. `age` mixes years and months

For 515 items with "NN YR" in the name, `age` equals NN, so years is the main unit.
But some values are months, and some match nothing. 11,885 rows (85%) are 0.

| item_no | im_desc | age |
|---|---|---|
| 901891 | Juan in a Million 116 month Extra Anejo | 116 |
| 20368 | Old Forester Bourbon 86prf | 48 |
| 16446 | Hard Truth Sweet Mash Four Grain Bourbon BIB | 60 |
| 900793 | HA WhistlePig 18yr Double Malt Whiskey | 128 |
| 906582 | Glenmorangie 12YO Original 4 1.75L Tray Pack | 18 |
| 906540 | Glengoyne Single Malt Scotch 50YR Decanter DISCO | 50 |

Values 48, 60 and 72 appear on 32 items, mostly Hard Truth and Old Forester; a
4-, 5- or 6-year age fits those (guess: months). Without a unit rule, `age` is only
safe as "as entered".

<details><summary>Query</summary>

```sql
with p as (
    select distinct item_no, im_desc, age::int as age,
        (regexp_match(im_desc, '(\d+) ?(?:YR|Year|YO)', 'i'))[1]::int as name_years
    from raw_iowa_liquor.products
)
select
    case when age = 0 then 'age 0'
         when age = name_years then 'age = years in name'
         else 'other' end as k,
    count(*)
from p
where name_years is not null
group by 1;

select distinct item_no, im_desc, age::int
from raw_iowa_liquor.products
where age::int >= 48
order by 3 desc;
```
</details>

### 4. Zero volume and proof

14 rows have `bottle_volume_ml = 0` and `proof = 0`: 13 "Ingredient …" bulk spirits
sold to Iowa distilleries (items 810000–880000) and 999998 "Iowa Spirits Magazine"
(all prices 0). One more row, 994830 "Dalmore 21YR" (750 ml), has `proof = 0`:
missing, not true.

<details><summary>Query</summary>

```sql
select item_no, category_name, im_desc, bottle_volume_ml, proof, state_bottle_retail
from raw_iowa_liquor.products
where bottle_volume_ml = '0' or proof = '0'
order by item_no;
```
</details>

### 5. `scc` is mostly placeholders

8 SCC values are each shared by many items, 8,775 items in all. 3,559 rows are NULL.

| scc | items |
|---|---|
| 10083664874139 | 5,760 |
| 10088004015142 | 769 |
| 10080686021312 | 600 |
| 08124050014724 | 559 |

<details><summary>Query</summary>

```sql
select scc, count(distinct item_no) as items
from raw_iowa_liquor.products
group by 1
having count(distinct item_no) > 1
order by 2 desc;
```
</details>

### 6. `upc` is not a product key

1,779 UPCs are shared by 4,169 items. Some sharing is the same liquid under another
item number (20319 "BP Old Ezra 7yr Bourbon" and 920319 "Old Ezra 7yr Bourbon BTB").
Some is unrelated products: UPC `088352142760` is on four different Dinastia Real
tequilas. 2 items have an all-zero UPC.

<details><summary>Query</summary>

```sql
select upc, count(distinct item_no) as items,
       string_agg(distinct im_desc, ' | ') as descs
from raw_iowa_liquor.products
group by 1
having count(distinct item_no) > 1
order by 2 desc;
```
</details>

### 7. `list_on` after the report date

110 rows (2026-12-01: 106, 2027-01-01: 4) are listed after `report_as_of` 2026-11-01.
21 of those items already have sales in `sales_2026`, so `list_on` is not the first
date an item could sell. Guess: scheduled re-listing date. By year, counts rise
steadily from 1963 to ~1,300–1,450 a year since 2022, with no spikes or gaps that
need action.

| item_no | im_desc | list_on |
|---|---|---|
| 69787 | Jagermeister Orange Liqueur | 2027-01-01 |
| 102616 | Doc Holliday Special Edition Straight Bourbon 10 Years | 2026-12-01 |

<details><summary>Query</summary>

```sql
select list_on, count(*) as rows,
       count(distinct item_no) filter (
           where item_no in (select item_no from raw_iowa_liquor.sales_2026)
       ) as items_with_2026_sales
from raw_iowa_liquor.products
where list_on > report_as_of
group by 1
order by 1;
```
</details>

### 8. `state_case_cost` ≠ bottle cost × pack

145 items differ by more than a cent. Most are cent rounding, but 30 are off by more
than 2%, usually by a whole multiple, as if the case cost used another pack size.

| item_no | im_desc | pack | bottle cost | case cost |
|---|---|---|---|---|
| 810005 | Ingredient Cedar Ridge Whiskey | 1 | 27.49 | 329.88 |
| 962095 | Kirkland Signature Spiced Rum Egg Nog | 6 | 7.99 | 120.00 |
| 986990 | Cedar Ridge Sir Maple Bourbon Whiskey | 6 | 115.50 | 115.50 |

<details><summary>Query</summary>

```sql
select distinct item_no, im_desc, pack, state_bottle_cost, state_case_cost,
       round(state_case_cost::numeric / nullif(state_bottle_cost::numeric * pack::int, 0), 2) as ratio
from raw_iowa_liquor.products
where abs(state_case_cost::numeric / nullif(state_bottle_cost::numeric * pack::int, 0) - 1) > 0.02
order by ratio;
```
</details>

### 9. Bottle prices off the 1.5 markup

Retail is 1.5 × cost on 14,008 rows. 13 items are off. 920301 "Old Elk Wheated
Bourbon Single Barrel" has cost 1,250 and retail 60 (guess: cost typo). 967472 "Flor
de Cana Spresso Coffee Liqueur" has cost = retail = 15. The top prices (37,500 cost
for 915767 "HA Midleton Silent Distillery Chapter 5") are rare whiskies and look
real; 915417 at 9,999.99 looks like a price, not a sentinel (guess).

<details><summary>Query</summary>

```sql
select distinct item_no, im_desc, state_bottle_cost, state_bottle_retail,
       round(state_bottle_retail::numeric / nullif(state_bottle_cost::numeric, 0), 2) as ratio
from raw_iowa_liquor.products
where abs(state_bottle_retail::numeric - state_bottle_cost::numeric * 1.5) > 0.02
order by ratio;
```
</details>
