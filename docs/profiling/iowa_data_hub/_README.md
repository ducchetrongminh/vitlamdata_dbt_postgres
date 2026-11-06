# iowa_data_hub

Iowa liquor product catalog and sales from the Iowa Data Hub (data.iowa.gov), published by
the Iowa Alcoholic Beverages Division (ABD) under CC BY 4.0.

- **How it is created:** the publisher's dataset page (dataset 1029) shows the catalog is a
  SELECT over ABD's product table (`iowa_data_hub_silver_prod.liquor_products`, from an MSSQL
  connector), renaming columns (`ITEMNO` → `item_no`, `BOTTLESIZE` → `bottle_volume_ml`,
  `DATE_` → `report_as_of`, …). The publisher declares `item_no` as the unique identifier and
  says the data updates monthly. Who enters products and how categories are assigned is
  unknown (question 2).
- **How it is loaded:** `ingestion/iowa_data_hub/pipeline.py` (dlt) downloads the CSV export.
  Every column lands as text (`varchar`), and an empty cell becomes NULL. `liquor_products` is
  replaced whole on each run, so it holds only the latest monthly snapshot, with no history.
  Each `liquor_sales_<year>` table is replaced whole. Past years load once. The latest year reloads
  on every run. The export can repeat a slice of lines (2025 #1).
- **Publisher docs:** the dataset page gives column labels, the source SQL and the unique
  identifier. Every column description on the page is empty, so there is no data
  dictionary. Codes and units are not defined (questions 3–6). The yearly sales pages
  (datasets 1262 for 2025, 1263 for 2026) do describe each column, give the source SQL (a
  year's slice of `iowa_data_hub_gold_prod.liquor_sales_combined`) and declare `invoice_id`
  unique. On the 2026 page the descriptions are shifted by one column (liquor_sales_2026.md).

| Table | Rows | Grain | Profile |
|---|---|---|---|
| `liquor_products` | 14,040 | one row per item per category (`item_no`, `category_name`), not per item | [liquor_products.md](liquor_products.md) |
| `liquor_sales_2026` | 2,029,764 | one row per invoice line; no unique key (2026 #1) | [liquor_sales_2026.md](liquor_sales_2026.md), the reference for the other years |
| `liquor_sales_2025` | 3,007,599 (516,986 of them repeated by the export) | one row per invoice line; `invoice_id` unique until 2025-08-29 (2025 #4) | [liquor_sales_2025.md](liquor_sales_2025.md) |
| `liquor_sales_2024` | 2,590,975 | one row per invoice line; `invoice_id` unique | [liquor_sales_2024.md](liquor_sales_2024.md) |
| `liquor_sales_2023` | 2,639,557 | one row per invoice line; `invoice_id` unique | [liquor_sales_2023.md](liquor_sales_2023.md) |
| `liquor_sales_2022` | 2,958,969 (394,404 of them repeated by the export) | one row per invoice line; `invoice_id` unique on distinct rows | [liquor_sales_2022.md](liquor_sales_2022.md) |
| `liquor_sales_2021` | 3,098,706 (475,994 of them repeated by the export) | one row per invoice line; `invoice_id` unique on distinct rows | [liquor_sales_2021.md](liquor_sales_2021.md) |
| `liquor_sales_2020` | 3,147,745 (533,380 of them repeated by the export) | one row per invoice line; `invoice_id` unique on distinct rows | [liquor_sales_2020.md](liquor_sales_2020.md) |
| `liquor_sales_2019` | 2,380,345 | one row per invoice line; `invoice_id` unique | [liquor_sales_2019.md](liquor_sales_2019.md) |
| `liquor_sales_2018` | 2,355,558 | one row per invoice line; `invoice_id` unique | [liquor_sales_2018.md](liquor_sales_2018.md) |
| `liquor_sales_2017` | 2,291,276 | one row per invoice line; `invoice_id` unique | [liquor_sales_2017.md](liquor_sales_2017.md) |
| `liquor_sales_2016` | 2,279,893 | one row per invoice line; `invoice_id` unique | [liquor_sales_2016.md](liquor_sales_2016.md) |
| `liquor_sales_2015` | 2,184,483 | one row per invoice line; `invoice_id` unique | [liquor_sales_2015.md](liquor_sales_2015.md) |
| `liquor_sales_2012` … `liquor_sales_2014` | 2.0M–3.2M each (catalog estimate) | not profiled | — |

## Relationships

- `liquor_sales_<year>.item_no` → `liquor_products.item_no`, many to one. Taken from the shared column and
  the publisher's statement that `item_no` identifies a product. No database constraint
  exists: the raw schema has no constraints. Confirm this with
  the human (question 1). Tested on a 1% sample (`TABLESAMPLE SYSTEM (1) REPEATABLE (42)`) of
  three years, then on all rows of 2025 and 2026:

  | Sales year | Sampled lines | Orphan lines | Sampled items | Orphan items |
  |---|---|---|---|---|
  | 2012 | 20,030 | 1,910 (9.5%) | 1,476 | 446 |
  | 2019 | 22,867 | 425 (1.9%) | 2,053 | 230 |
  | 2026 | 19,452 | 0 | 2,615 | 0 |
  | 2015, all rows | 2,184,483 | 156,750 | 3,595 | 1,735 |
  | 2016, all rows | 2,279,893 | 127,120 | 3,724 | 1,606 |
  | 2017, all rows | 2,291,276 | 103,219 | 3,901 | 1,523 |
  | 2018, all rows | 2,355,558 | 86,439 | 3,954 | 1,331 |
  | 2019, all rows | 2,380,345 | 47,897 | 4,008 | 975 |
  | 2020, all rows | 3,147,745 | 10,172 | 4,176 | 400 |
  | 2021, all rows | 3,098,706 | 1,949 | 4,472 | 14 |
  | 2022, all rows | 2,958,969 | 12 | 4,786 | 2 |
  | 2023, all rows | 2,639,557 | 0 | 5,231 | 0 |
  | 2024, all rows | 2,590,975 | 0 | 5,211 | 0 |
  | 2025, all rows | 3,007,599 | 0 | 5,048 | 0 |
  | 2026, all rows | 2,029,764 | 0 | 4,792 | 0 |

  Orphans grow with age. `liquor_products` is a current snapshot replaced on every load, so items
  sold in the past but no longer in the catalog are missing, e.g. `73050 RUMCHATA` and
  `11293 CROWN ROYAL CANADIAN WHISKY` in 2012. This is a guess: they could also have been
  renumbered (question 1). The orphans are not a format mismatch. Both sides are all digits,
  and stripping leading zeros finds no extra matches. A product dimension built only from
  `liquor_products` will miss these items. Their attributes would have to come from the sales lines,
  which carry `im_desc`, `pack`, `bottle_volume_ml` and `vendor_number`.

  <details><summary>Query</summary>

  ```sql
  -- swap the year to test another table; drop the tablesample for all rows
  with s as (select item_no from raw_iowa_data_hub.liquor_sales_2012 tablesample system (1) repeatable (42)),
       p as (select item_no, count(*) as n from raw_iowa_data_hub.liquor_products group by 1)
  select count(*) as lines, count(*) filter (where p.item_no is null) as orphan_lines,
         count(distinct s.item_no) as items,
         count(distinct s.item_no) filter (where p.item_no is null) as orphan_items,
         count(*) filter (where p.n > 1) as lines_multi_category
  from s left join p using (item_no);
  ```
  </details>
- Sales carry one `category_name` per line, in upper case
  (`TEMPORARY & SPECIALTY PACKAGES`). Products use mixed case. Sales also carry a
  `category_code`, but products do not. A join on category needs `upper()` on both sides.
  The sales category is the item's category at the time of sale and changes over time,
  e.g. in and out of `TEMPORARY & SPECIALTY PACKAGES` (2026 #4). `IOWA SPIRITS
  MANUFACTURERS` never appears on a sales line. Since 2025-07-01 the sales names match the
  `liquor_products` names in upper case. Before, four names were plural (2025 #5).
- Cardinality: `liquor_products` has 2,354 items listed under 2 or 3 categories (products issue #1).
  In the 2026 sample, 6.2% of sales lines (1,206 of 19,452) are for such items. On all rows it
  is 6.0% in both years (178,823 lines in 2025, including the repeats of 2025 #1; 121,269 in 2026). A join on `item_no` alone
  multiplies those lines. Joining on (`item_no`, `upper(category_name)`) avoids that: in Oct
  2026, every sales line's category is one of its item's `liquor_products` categories.
- Attributes: sales lines carry the item's description, vendor, pack, volume, cost and
  retail as of the sale. They change over time (2026 #6). In Oct 2026 all of them match the
  current `liquor_products` row on every line. Older lines may differ.

## Questions for the human

1. Is `liquor_sales.item_no` → `liquor_products.item_no` the intended join? Do sales use the same item
   numbers as the current catalog, including for delisted items?
2. Why do 2,354 items appear under more than one category (products issue #1)? Guess:
   `Temporary & Specialty Packages` and `Iowa Spirits Manufacturers` are extra groupings
   added on top of a product's main category. Which category is the item's real one?
3. `age` is text in the publisher's own SQL, unlike the other numeric fields. What unit
   does it use, and what does `0` mean?
4. Is `inner_pack` the number of bottles inside one sellable unit, as with
   "Johnnie Walker Black w/2-50mls" having `inner_pack = 3`?
5. What is `scc`? It has only 8 distinct values over 10,481 rows, so it cannot be a
   per-product shipping-container code (products issue #4).
6. What do the codes in `im_desc` mean (`DISCO`, `HA`, `BP`, `USE CODE n`, `NO VOR`, `DNO`,
   `Ingredient`)? Should the 13 "Ingredient" items and `999998 Iowa Spirits Magazine` stay
   in the product dimension? (products issues #6, #10)
7. Price and pack errors: is Old Elk 920301 bottle cost `1250` a typo for `40`? Which value
   is wrong on the 36 rows where case cost ≠ bottle cost × pack? (products issues #7, #8)
8. Sales `invoice_id` has held only the invoice number since 2025-09-01, without the line
   number, and no column set is unique (2026 #1). Can the publisher restore a line number?
   If not, is a line key built in staging from the row's content acceptable, given that an
   invoice can repeat an identical line?
9. The 2025 export repeats a slice of lines in an extra CSV part: 516,986 extra rows, ordered
   2025-07-29 – 2025-10-14 (2025 #1). The slice moved between downloads. The 2022, 2021 and
   2020 exports do the same at year end (394,404, 475,994 and 533,380 extra rows). Without the repeats
   the table matches the publisher's count exactly. Should the loader skip a part whose rows
   all appear in an earlier part? Should we report the export bug to the publisher?
10. Cost, retail, dollars, liters and gallons are rounded to whole numbers on all lines from
    2025-11-01 to 2026-01-31 (2026 #2, 2025 table). Is the publisher aware? Do we accept rounded money for
    those three months, or take prices from elsewhere?
11. `sales_dollars` ≠ bottles × `state_bottle_retail` on 1–3% of lines (2026 #3). Which one is
    the amount the store paid? Are these discounts?
12. Store 2687 has zip `57222` (South Dakota). Is `52722` (Bettendorf) correct? (2026 #5)
13. Item 921635 `TEMPLETON USA 250 STRAIGHT BOURBON WHISKEY` has no category on 26 lines in
    2026 (2026 #4). Which category is it?
14. Stores 010830 and 010860 each carry two names on the same days, in different towns
    (`VENTURA TOWN MART` and `GARNER TOWN MART`; `PUMP & PANTRY 70` and `HY-VEE GAS`). Were
    those lines keyed to the wrong store number? (2026 #5)
15. On 2018-10-01, 42 minis switch `bottle_volume_ml` from one bottle to the pack's total
    (2018 #1). On 2019-08-01, 106 items switch `bottle_volume_ml` from the pack's total to one bottle (2019 #1).
    Before 2025-09-01, 18 more multi-pack items carry the pack's total ml in `bottle_volume_ml`
    (Twisted Shotz party pack 1,800 ml), and one bottle's ml after (25 ml) (2025 #2). Is the
    newer value right? Then liters before Sep 2025 are overstated for these items. Two
    Twisted Tea items drop 750 → 25 ml and 50 → 25 ml: is 25 correct for them?
16. In Jan–Mar 2024, 26 new items carry a group-level category code ending `000` (360 lines all through 2023) (`1082000
    IMPORTED CORDIALS & LIQUEURS`), with the same name as a regular code (`1082100`) (2024 #1).
    Should staging map each group code to the regular code with the same name?
17. Around 2022-07-18 several codes change at once (2022 #1). Category `1071100` becomes
    `1071000`, `1901200` becomes `1901000`, and most `1082000` items move to `1082100`. Returns
    (`RINV-`) and 6-digit store numbers first appear. Was there a system change then? Were
    returns before it left out of the data?
18. In 2017 (833 lines) and Jan–Jul 2018 (500 lines), lines have bottles but `sales_dollars` = 0 (2018 #2). Are
    these free goods or samples? Should they count in bottles sold?
19. Until 2016-08-26 sales use an older category taxonomy (2016 #1), and some codes mean
    another category after (`1011300` TENNESSEE WHISKIES, then SINGLE BARREL BOURBON
    WHISKIES). Is there a mapping from the old codes to the new? Without one, staging must
    key category on (code, period).
