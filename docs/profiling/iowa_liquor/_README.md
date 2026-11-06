# iowa_liquor

Iowa liquor product catalog and sales from the Iowa Data Hub (data.iowa.gov), published by
the Iowa Alcoholic Beverages Division (ABD) under CC BY 4.0.

- **How it is created:** the publisher's dataset page (dataset 1029) shows the catalog is a
  SELECT over ABD's product table (`iowa_data_hub_silver_prod.liquor_products`, from an MSSQL
  connector), renaming columns (`ITEMNO` → `item_no`, `BOTTLESIZE` → `bottle_volume_ml`,
  `DATE_` → `report_as_of`, …). The publisher declares `item_no` as the unique identifier and
  says the data updates monthly. Who enters products and how categories are assigned is
  unknown (question 2).
- **How it is loaded:** `ingestion/iowa_liquor/pipeline.py` (dlt) downloads the CSV export.
  Every column lands as text (`varchar`), and an empty cell becomes NULL. `products` is
  replaced whole on each run, so it holds only the latest monthly snapshot, with no history.
  Each `sales_<year>` table is replaced whole. Past years load once. The latest year reloads
  on every run.
- **Publisher docs:** the dataset page gives column labels, the source SQL and the unique
  identifier. Every column description on the page is empty, so there is no data
  dictionary. Codes and units are not defined (questions 3–6).

| Table | Rows | Grain | Profile |
|---|---|---|---|
| `products` | 14,040 | one row per item per category (`item_no`, `category_name`), not per item | [products.md](products.md) |
| `sales_2012` … `sales_2026` | 2.0M–3.2M each (catalog estimate) | not profiled | — |

## Relationships

- `sales_<year>.item_no` → `products.item_no`, many to one. Taken from the shared column and
  the publisher's statement that `item_no` identifies a product. No database constraint
  exists: the only constraint on `products` is dlt's `UNIQUE (_dlt_id)`. Confirm this with
  the human (question 1). Tested on a 1% sample (`TABLESAMPLE SYSTEM (1) REPEATABLE (42)`) of
  three years:

  | Sales year | Sampled lines | Orphan lines | Sampled items | Orphan items |
  |---|---|---|---|---|
  | 2012 | 20,030 | 1,910 (9.5%) | 1,476 | 446 |
  | 2019 | 22,867 | 425 (1.9%) | 2,053 | 230 |
  | 2026 | 19,452 | 0 | 2,615 | 0 |

  Orphans grow with age. `products` is a current snapshot replaced on every load, so items
  sold in the past but no longer in the catalog are missing, e.g. `73050 RUMCHATA` and
  `11293 CROWN ROYAL CANADIAN WHISKY` in 2012. This is a guess: they could also have been
  renumbered (question 1). The orphans are not a format mismatch. Both sides are all digits,
  and stripping leading zeros finds no extra matches. A product dimension built only from
  `products` will miss these items. Their attributes would have to come from the sales lines,
  which carry `im_desc`, `pack`, `bottle_volume_ml` and `vendor_number`.

  <details><summary>Query</summary>

  ```sql
  -- swap the year to test another table
  with s as (select item_no from raw_iowa_liquor.sales_2012 tablesample system (1) repeatable (42)),
       p as (select item_no, count(*) as n from raw_iowa_liquor.products group by 1)
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
- Cardinality: `products` has 2,354 items listed under 2 or 3 categories (products issue #1).
  In the 2026 sample, 6.2% of sales lines (1,206 of 19,452) are for such items. A join on
  `item_no` alone multiplies those lines.

## Questions for the human

1. Is `sales.item_no` → `products.item_no` the intended join? Do sales use the same item
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
