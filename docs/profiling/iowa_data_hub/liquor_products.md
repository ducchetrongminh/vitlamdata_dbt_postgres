# raw_iowa_data_hub.liquor_products

Profiled 2026-11-06, data as of load `1793883467.6571584` (loaded 2026-11-05 20:01 +07,
`report_as_of` 2026-11-01). 14,040 rows (all checks are full scans: the table is small). One row
is one item in one category (`item_no`, `category_name`), **not one item**: see #1.

## Columns

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `item_no` | text | `100015`, `27102`, `957303` | | all digits, length 3–7; 11,668 distinct (#1) |
| `category_name` | text | `Straight Bourbon Whiskies`, `Temporary & Specialty Packages` | | 48 values, near-duplicates (#2) |
| `im_desc` | text | `Flor de Cana Eco`, `Gin Mare USE CODE 928527` | | carries status codes (#10); 8 rows with broken encoding (#11) |
| `vendor_no` | text | `035`, `085`, `947` | | always 3 digits: keep as text (leading zeros); 393 values, 1:1 with `vendor_name` |
| `vendor_name` | text | `DIAGEO AMERICAS`, `Brown Forman Corp.` | | 44 of 393 names in all caps; one has a double space (#11) |
| `bottle_volume_ml` | text → int | | 0 – 5,250 | 750 on 9,558 rows; 14 zeros (#6) |
| `pack` | text → int | | 1 – 120 | 6 on 8,229 rows, 12 on 3,903 |
| `inner_pack` | text → int | | 1 – 300 | 1 on 12,601 rows; meaning unclear (README Q4) |
| `age` | text → int | | 0 – 128 | 0 on 11,885 rows; mixes years and months (#5) |
| `proof` | text → numeric | | 0 – 190 | 15 zeros (#6) |
| `list_on` | text → date | | 1963-06-01 – 2027-01-01 | 110 future dates (#3); 97% fall on the 1st of a month |
| `upc` | text | `855153005026`, `026964100174` | | always 12 digits; 2 all-zero; shared across unrelated items (#9) |
| `scc` | text | `10083664874139`, `1008519260047` | | 3,559 NULL; only 8 distinct values (#4) |
| `state_bottle_cost` | text → numeric | | 0 – 37,500 | 1 zero; 1 typo (#7) |
| `state_case_cost` | text → numeric | | 0 – 37,500 | 36 rows differ from bottle cost × pack (#8) |
| `state_bottle_retail` | text → numeric | | 0 – 56,250 | 1.5 × bottle cost on 14,008 rows (#7) |
| `report_as_of` | text → date | | 2026-11-01 | one value: the snapshot date |
| `_dlt_load_id` | text | `1793883467.6571584` | | one load (replace) |
| `_dlt_id` | text | `TeAMEuoNc2EXpQ` | | dlt row id, unique |

- Nulls: none, except `scc`.
- Casts: clean. All 8 numeric columns match `^-?[0-9]+(\.[0-9]+)?$`, and both date columns
  match `YYYY-MM-DD`.
- No negatives in any numeric column.
- The top prices are real. They are ultra-rare whiskies at the normal 1.5× markup, e.g.
  Midleton Silent Distillery $56,250 retail, and `9999.99` cost / `14999.99` retail for
  Midleton Very Rare 40th. Retail bins:

| Retail | Rows |
|---|---|
| 0 | 1 |
| 0.50 – 9.99 | 1,691 |
| 10 – 24.99 | 4,813 |
| 25 – 49.99 | 4,093 |
| 50 – 99.99 | 2,436 |
| 100 – 249.99 | 741 |
| 250 – 999.99 | 196 |
| 1,000 – 4,999.99 | 58 |
| 5,000+ | 11 |

## Issues

| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `item_no` | Not unique: 2,354 items are listed under 2–3 categories | ask (README Q2). Then staging either keeps grain (`item_no`, `category_name`) or picks one category per item | open |
| 2 | `category_name` | Near-duplicate values (singular vs plural), 11 rows | clean in staging: map `American Cordials & Liqueurs` → `American Cordials & Liqueur`, `Imported Cordials & Liqueurs` → `Imported Cordials & Liqueur`, `Imported Vodka` → `Imported Vodkas` | open |
| 3 | `list_on` | 110 dates after the snapshot date | ask: listed ahead of release? If so, accept | open |
| 4 | `scc` | 8 distinct values over 10,481 rows: not a per-item code | ask (README Q5) | open |
| 5 | `age` | Mixes years and months | ask (README Q3) | open |
| 6 | `bottle_volume_ml`, `proof` | 0 on 13 "Ingredient" items, a magazine, and one whisky | clean in staging: 0 → NULL; ask whether non-retail items stay in the product dim | open |
| 7 | `state_bottle_cost` | One bottle cost is a typo; 17 rows are off the 1.5× markup | ask | open |
| 8 | `state_case_cost` | 36 rows differ from bottle cost × pack by more than rounding | ask | open |
| 9 | `upc` | 2 all-zero placeholders; 1,779 UPCs shared by 4,169 unrelated items | clean in staging: all-zero → NULL; do not use `upc` as a key | open |
| 10 | `im_desc` | Status codes inside the description (`DISCO`, `HA`, `USE CODE`, …) | ask (README Q6) | open |
| 11 | `im_desc`, `vendor_name` | Double spaces, edge spaces, mis-encoded characters | clean in staging: trim and squeeze spaces; ask whether to repair the 8 broken rows | open |

### 1. `item_no` is not unique

14,040 rows but 11,668 distinct `item_no`. 2,336 items have 2 rows and 18 have 3. Within each
duplicated item, every column is the same except `category_name`.
(`item_no`, `category_name`) is unique. The extra category is nearly always one of two
groupings:

| Categories of the item (2-row items) | Items |
|---|---|
| real category + `Temporary & Specialty Packages` | 1,715 |
| real category + `Iowa Spirits Manufacturers` | 615 |
| two ordinary categories | 6 |

Five of the 18 three-row items were inspected. Four carry both groupings plus a real
category, e.g. 17658: `Iowa Spirits Manufacturers | Straight Bourbon Whiskies | Temporary &
Specialty Packages`. One (2511) carries `Temporary & Specialty Packages` plus two ordinary
categories.

The 6 two-ordinary pairs:
- `Bottled in Bond Bourbon` / `Straight Bourbon Whiskies` (16017, 20920)
- `Blended Whiskies` / `Straight Bourbon Whiskies` (17543)
- `100% Agave Tequila` / `Mixto Tequila` (89841)
- `Special Order Items` plus a spirit category (905377, 907699)

Only 4 of the 1,737 `Temporary & Specialty Packages` rows belong to items with no other
category. Sales lines carry one category each. In a 1% sample of `liquor_sales_2026`, 6.2% of lines
are for items with more than one category, so a join on `item_no` alone multiplies those lines.
Guess: the two groupings are tags added on top of the real category.

<details><summary>Query</summary>

```sql
-- shape of the duplication
select n, count(*) as items
from (select item_no, count(*) as n from raw_iowa_data_hub.liquor_products group by 1) s
group by 1 order by 1;

-- only category_name differs (returns 0)
select count(*) from (
  select item_no from raw_iowa_data_hub.liquor_products group by 1
  having count(*) > 1
     and count(distinct (im_desc, vendor_no, vendor_name, bottle_volume_ml, pack, inner_pack,
                         age, proof, list_on, upc, coalesce(scc, '~'), state_bottle_cost,
                         state_case_cost, state_bottle_retail)) > 1) s;

-- (item_no, category_name) is unique
select count(*), count(distinct (item_no, category_name)) from raw_iowa_data_hub.liquor_products;

-- which categories duplicated items carry
select item_no, im_desc, string_agg(category_name, ' | ' order by category_name) as cats
from raw_iowa_data_hub.liquor_products group by 1, 2 having count(*) > 1 order by 1;
```
</details>

### 2. `category_name` has near-duplicate values

Sorted by value, three rare names sit next to a common twin:

| category_name | rows |
|---|---|
| `American Cordials & Liqueur` | 381 |
| `American Cordials & Liqueurs` | 3 |
| `Imported Cordials & Liqueur` | 471 |
| `Imported Cordials & Liqueurs` | 3 |
| `Imported Vodka` | 5 |
| `Imported Vodkas` | 202 |

All 11 rare-name rows were listed between 2022-09-01 and 2023-06-01. Most are gift packs
(`Grey Goose Glass Pack`, `St Germain w/Acrylic Carafe`). Guess: a short-lived naming
variant. The mapping in Action assumes the majority form is correct.

<details><summary>Query</summary>

```sql
select category_name, count(*) from raw_iowa_data_hub.liquor_products group by 1 order by 1;

select item_no, category_name, im_desc, vendor_name, list_on
from raw_iowa_data_hub.liquor_products
where category_name in ('American Cordials & Liqueurs', 'Imported Cordials & Liqueurs', 'Imported Vodka')
order by 2, 1;
```
</details>

### 3. `list_on` has 110 future dates

The snapshot is dated 2026-11-01. 106 rows have `list_on` 2026-12-01 and 4 have 2027-01-01.
Recent months are steady (2026-09: 251, 2026-10: 268, 2026-11: 215), so these look like
items listed ahead of release (guess). The rest of the year distribution is a smooth climb:
1963 has 1 row, the 1970s–2000s have 1–52 per year, then volume jumps from 2020 (992) and
reaches 1,891 in 2026. There are no gaps, spikes or defaults.

<details><summary>Query</summary>

```sql
select extract(year from list_on::date)::int as year, count(*)
from raw_iowa_data_hub.liquor_products group by 1 order by 1;

select list_on, count(*) from raw_iowa_data_hub.liquor_products
where list_on::date > report_as_of::date group by 1 order by 1;
```
</details>

### 4. `scc` is not a per-item code

10,481 non-NULL rows share only 8 values. `10083664874139` alone covers 7,200 rows (5,760
items) across unrelated brands. One value, `1008519260047`, is 13 digits where the others
are 14.

| scc | rows | items |
|---|---|---|
| `10083664874139` | 7,200 | 5,760 |
| NULL | 3,559 | 2,893 |
| `10088004015142` | 891 | 769 |
| `10080686021312` | 644 | 600 |
| `08124050014724` | 596 | 559 |
| `1008519260047` | 541 | 511 |
| `10000513072935` | 371 | 351 |
| `00082000748687` | 127 | 119 |
| `00082000768142` | 111 | 106 |

<details><summary>Query</summary>

```sql
select scc, length(scc), count(*), count(distinct item_no)
from raw_iowa_data_hub.liquor_products group by 1 order by 3 desc;
```
</details>

### 5. `age` mixes years and months

`age` is 0 on 11,885 rows (85%). Some descriptions state the unit, and the value does not
always match it:

| item_no | im_desc | age |
|---|---|---|
| 901891 | Juan in a Million 116 month Extra Anejo | 116 |
| 900793 | HA WhistlePig 18yr Double Malt Whiskey | 128 |
| 18382 | Fox and Oden Straight Bourbon Whiskey | 121 |
| 907778 | HA Glenlivet 40YR | 40 |
| 906540 | Glengoyne Single Malt Scotch 50YR Decanter DISCO | 50 |

Hard Truth products use 48, 60 and 72 (4, 5 and 6 years in months). Old Forester uses 48.
Extra añejo tequilas use 48–81. So 116 is months, 40 and 50 are years, and the WhistlePig
"18yr" at 128 fits neither unit. It is unclear whether 0 means "no age statement" or
"unknown".

<details><summary>Query</summary>

```sql
select age::int, count(*) from raw_iowa_data_hub.liquor_products group by 1 order by 1;

select item_no, im_desc, category_name, age::int
from raw_iowa_data_hub.liquor_products where age::int >= 40 order by 4 desc, 1;
```
</details>

### 6. Zero volume and proof on non-retail items

The 14 rows with `bottle_volume_ml = 0` are 13 "Ingredient" items (item_no 810000–880000,
e.g. `Ingredient Cats Eye Distillery Vodka`) and `999998 Iowa Spirits Magazine`. The
magazine row also has 0 in every price. Each of these rows also has `proof = 0`. The 15th
`proof = 0` row is a real whisky, `994830 Dalmore 21YR`, so its proof is missing.

<details><summary>Query</summary>

```sql
select item_no, category_name, im_desc, bottle_volume_ml, proof,
       state_bottle_cost, state_case_cost, state_bottle_retail
from raw_iowa_data_hub.liquor_products
where bottle_volume_ml::numeric = 0 or proof::numeric = 0
   or state_bottle_cost::numeric = 0 or state_bottle_retail::numeric = 0
order by 1;
```
</details>

### 7. Bottle cost typo and off-markup prices

`state_bottle_retail` is exactly 1.50 × `state_bottle_cost` on 14,008 rows. Another 14 rows
are at 1.51–1.52, which is rounding. 17 rows are further off. One is a clear typo:

| item_no | im_desc | pack | bottle cost | case cost | retail |
|---|---|---|---|---|---|
| 920301 | Old Elk Wheated Bourbon Single Barrel | 6 | 1250 | 240 | 60 |

Case cost ÷ pack = 40, and 40 × 1.5 = 60, so the bottle cost should be 40. The rest range from
1.00× (`967472 Flor de Cana Spresso`, cost = retail = 15) to 3.13× (`986503 Howler Head KSB
Banana`). One row has no ratio: the magazine, with cost 0.

<details><summary>Query</summary>

```sql
select item_no, category_name, im_desc, pack, state_bottle_cost, state_case_cost, state_bottle_retail,
       round(state_bottle_retail::numeric / nullif(state_bottle_cost::numeric, 0), 2) as markup
from raw_iowa_data_hub.liquor_products
where round(state_bottle_retail::numeric / nullif(state_bottle_cost::numeric, 0), 2) not between 1.49 and 1.52
order by markup;
```
</details>

### 8. Case cost differs from bottle cost × pack

13,885 rows match within 2 cents. 119 more are within 1%, which is rounding. 36 rows differ
by more, e.g.:

| item_no | im_desc | pack | bottle cost | case cost | expected |
|---|---|---|---|---|---|
| 36723 | Iowa Legendary Rye Vodka | 6 | 7.75 | 90 | 46.50 |
| 37578 | Have Sextro Vodka | 6 | 8 | 120 | 48 |
| 24960 | Soda Jerk Root Beer Shot Mini DNO | 6 | 16.5 | 198 | 99 |
| 830000 | Ingredient Cats Eye Distillery Vodka | 1 | 28.5 | 171 | 28.50 |

Either `pack` or a cost is wrong on these rows. Only the human or the source can say which.

<details><summary>Query</summary>

```sql
select item_no, im_desc, pack, state_bottle_cost, state_case_cost,
       state_bottle_cost::numeric * pack::numeric as expected
from raw_iowa_data_hub.liquor_products
where abs(state_case_cost::numeric / nullif(state_bottle_cost::numeric * pack::numeric, 0) - 1) > 0.01
order by 1;
```
</details>

### 9. `upc` has placeholders and is shared across unrelated items

2 rows have `000000000000`, both from AMERICAN SPIRITS EXCHANGE (901976, 919444). Beyond
that, 1,779 UPCs are each shared by 2 or more items, 4,169 items in all, and the products
are unrelated. For example, `855675001186` is on 12 items, from `7 Drops Apple` to `Staria
Hibiscus Liqueur DISCO`.

<details><summary>Query</summary>

```sql
select upc, count(distinct item_no) as items, min(im_desc), max(im_desc)
from raw_iowa_data_hub.liquor_products group by 1 having count(distinct item_no) > 1
order by 2 desc limit 20;

select item_no, im_desc, vendor_name from raw_iowa_data_hub.liquor_products where upc ~ '^0+$';
```
</details>

### 10. `im_desc` carries status codes

Codes are embedded in the description text:

| Code | Rows | Example |
|---|---|---|
| `DISCO` | 757 | `Vat 69 Scotch DISCO` |
| `HA ` prefix | 641 | `HA Glenlivet 40YR` |
| `USE CODE` | 380 | `Gin Mare USE CODE 928527` |
| `BP ` prefix | 216 | `BP Old Ezra 7yr Bourbon` |
| `NO VOR` | 44 | `Pravda Vodka NO VOR` |
| `Ingredient ` prefix | 13 | `Ingredient Cedar Ridge Whiskey` |

Guesses:
- `DISCO`: discontinued.
- `USE CODE n`: replaced by item n.
- `HA`: high allocation.
- `BP`: barrel pick.

Their meanings are not documented. `DNO` (24960) may be another code.

<details><summary>Query</summary>

```sql
select tag, count(*)
from raw_iowa_data_hub.liquor_products,
     lateral (values ('DISCO', im_desc ~ '\mDISCO\M'), ('USE CODE', im_desc ~* 'use code'),
                     ('HA prefix', im_desc ~ '^HA '), ('BP prefix', im_desc ~ '^BP '),
                     ('NO VOR', im_desc ~ 'NO VOR'), ('Ingredient', im_desc ~ '^Ingredient ')) t(tag, hit)
where hit group by 1 order by 2 desc;
```
</details>

### 11. Whitespace and encoding in text

| Column | Edge spaces | Double spaces | Non-ASCII |
|---|---|---|---|
| `vendor_name` | 0 | 1,575 rows (one name: `SAZERAC COMPANY  INC`) | 0 |
| `im_desc` | 2 | 56 | 20 |

8 of the 20 non-ASCII `im_desc` rows are UTF-8 decoded twice, e.g. `DeKuyper Triple Sec 30Â°
PET`, with `Ã±` in place of `ñ`. The other 12 are real accents (`è`, `ñ`, `Ø`) or
invisible space characters (not identified). `category_name` is clean. `vendor_name` casing is mixed: 44 of 393 names
are all caps.

<details><summary>Query</summary>

```sql
select col, count(*) filter (where v <> btrim(v)) as edge_ws,
       count(*) filter (where v ~ '  ') as dbl_ws, count(*) filter (where v ~ '[^ -~]') as non_ascii
from raw_iowa_data_hub.liquor_products,
     lateral (values ('category_name', category_name), ('im_desc', im_desc), ('vendor_name', vendor_name)) t(col, v)
group by 1;

select item_no, im_desc from raw_iowa_data_hub.liquor_products where im_desc ~ '[ÃÂ]';
```
</details>
