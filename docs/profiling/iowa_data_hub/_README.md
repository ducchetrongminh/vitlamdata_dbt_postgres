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
| `liquor_sales_2014` | 2,097,796 | one row per invoice line; `invoice_id` unique | [liquor_sales_2014.md](liquor_sales_2014.md) |
| `liquor_sales_2013` | 2,063,763 | one row per invoice line; `invoice_id` unique | [liquor_sales_2013.md](liquor_sales_2013.md) |
| `liquor_sales_2012` | 2,082,059 | one row per invoice line; `invoice_id` unique | [liquor_sales_2012.md](liquor_sales_2012.md) |

## Relationships

- `liquor_sales_<year>.item_no` → `liquor_products.item_no`, many to one. Taken from the shared column and
  the publisher's statement that `item_no` identifies a product. No database constraint
  exists: the raw schema has no constraints. Confirmed by
  the human (question 1). Tested on all rows of every year (repeated lines of 2025 #1
  included):

  | Sales year | Lines | Orphan lines | Items | Orphan items |
  |---|---|---|---|---|
  | 2012 | 2,082,059 | 221,386 (10.6%) | 3,146 | 1,794 |
  | 2013 | 2,063,763 | 209,971 | 3,359 | 1,880 |
  | 2014 | 2,097,796 | 196,372 | 3,592 | 1,913 |
  | 2015 | 2,184,483 | 156,750 | 3,595 | 1,735 |
  | 2016 | 2,279,893 | 127,120 | 3,724 | 1,606 |
  | 2017 | 2,291,276 | 103,219 | 3,901 | 1,523 |
  | 2018 | 2,355,558 | 86,439 | 3,954 | 1,331 |
  | 2019 | 2,380,345 | 47,897 | 4,008 | 975 |
  | 2020 | 3,147,745 | 10,172 | 4,176 | 400 |
  | 2021 | 3,098,706 | 1,949 | 4,472 | 14 |
  | 2022 | 2,958,969 | 12 | 4,786 | 2 |
  | 2023 | 2,639,557 | 0 | 5,231 | 0 |
  | 2024 | 2,590,975 | 0 | 5,211 | 0 |
  | 2025 | 3,007,599 | 0 | 5,048 | 0 |
  | 2026 | 2,029,764 | 0 | 4,792 | 0 |

  Orphans grow with age. `liquor_products` is a current snapshot replaced on every load, so items
  sold in the past but no longer in the catalog are missing, e.g. `73050 RUMCHATA` and
  `11293 CROWN ROYAL CANADIAN WHISKY` in 2012. This is a guess: they could also have been
  renumbered (question 1). The orphans are not a format mismatch. Both sides are all digits,
  and stripping leading zeros finds no extra matches. A product dimension built only from
  `liquor_products` will miss these items. Their attributes would have to come from the sales lines,
  which carry `im_desc`, `pack`, `bottle_volume_ml` and `vendor_number`.

  <details><summary>Query</summary>

  ```sql
  -- swap the year to test another table
  with s as (select item_no from raw_iowa_data_hub.liquor_sales_2012),
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

## Decisions

Answers from the human, 2026-11-07. Each question keeps its number, so issue tables that cite
"README Qn" still point here. Questions still open are under
[Questions for the human](#questions-for-the-human), and those nobody can answer are under [Unknown](#unknown).

**Product attributes are type 1.** An item's category, name, volume and pack
change over time, mostly through fixes to wrong input (Q14–Q17, Q19). The product dimension
takes each item's latest value, with exceptions noted below. Lines keep their own values in staging.

1. **Is `item_no` → `liquor_products.item_no` the join?** Yes. Items missing from the catalog are
   built from the sales lines (Relationships).
2. **Which category is an item's real one?** Unknown. A product can change category over time.
   Decision: the catalog keeps its grain (`item_no`, `category_name`). The product dimension takes
   the item's latest category from the sales lines, skipping
   `TEMPORARY & SPECIALTY PACKAGES` when the item has another (Q14). Items never sold take their
   catalog category other than `Temporary & Specialty Packages`, if there is one.
3. **What unit is `age`?** Found: years, except for a few products entered in months.
   - The description states the age on 639 catalog rows, and `age` equals it on all of them but
     one: 900793 `WhistlePig 18yr` has 128.
   - Almost every value from 36 up without a stated age is a month count of a whiskey or añejo
     tequila:
     - Hard Truth: 36, 48, 60, 72.
     - Old Forester: 48.
     - Jack Daniel's Single Barrel: 48.
     - Woodford Reserve: 72.
     - Añejo and extra añejo tequilas: 36–81.
     - Fox and Oden: 121.
     - `Juan in a Million 116 month`: 116.
   - Exceptions: 915385 `Midleton Silent Distillery Chapter 5` at 49 is likely years (guess).
     907221 `Members Mark Highland Single Malt Scotch` at 36 is unclear.
   - Decision: in staging, take the age from the description when it states one. Otherwise,
     divide by 12 when `age` ≥ 36, except item 915385. Map 0 to NULL (no age stated). See products
     issue #5.
8. **Is there an invoice_id rule?** Yes, every value fits one. Full scan of all years:

   | Shape | Ordered on | Lines | Meaning |
   |---|---|---|---|
   | `S` + 11 digits | 2012-01-03 – 2016-08-26 | 9,880,762 | invoice (6) + line (5) |
   | `INV-` + 11 digits | 2016-08-29 – 2025-08-29 | 24,133,209 | invoice (6) + line (5) |
   | `RINV-` + 11 digits | 2022-07-20 – 2025-08-29 | 9,970 | return: invoice (6) + line (5) |
   | `INV-` + 6 digits | 2025-09-01 – 2026-09-14 | 2,840,113 | invoice only |
   | `INV-` + 7 digits | 2026-09-14 – | 340,922 | invoice only; the counter passed 990154 and gained a leading 0 |
   | `RINV-` + 6 digits | 2025-09-02 – | 2,612 | return, invoice only |
   | 6 one-off shapes in 2012, 2013 and 2015 | | 1,170 | still end in a 5-digit line number (2012 #2, 2013 #1, 2015 #1) |

   Rules for staging:
   - `is_return` = the id starts with `R`.
   - Up to 2025-08-29, the line number is the last 5 digits and the invoice is everything before
     them. From 2025-09-01 the id has no line number.
   - The invoice number alone is not unique. The S era (up to 341595) and the INV era (from 1)
     overlap. After the 2022-07-18 system change (2022 #1), invoices 450000 – 454720 were issued a
     second time to other stores. Their Feb 2022 lines are numbered after the July lines, so
     full ids stay unique. The invoice key is (invoice text, `store_no`, `ordered_on`).
   - The line key is `invoice_id` up to 2025-08-29. After that it is a hash of all columns,
     unique once whole-row repeats are dropped (Q9).
9. **Fix export repeats in the loader?** Not necessary. Decision: drop whole-row repeats in staging.
   This also drops the few repeated lines that are in the publisher's own table: 7 in 2025, 14 in 2026.
   - **Why they look real.** The table minus the export's extra part matches the publisher's row
     count exactly in 2025 and 2026, so the publisher holds them too. In 2025's repeated slice,
     the 5 such rows appear 4 times, not 2: twice in the publisher's table, then doubled by the
     export.
   - **When they occur.** All 21 are ordered from 2025-09-01, when `invoice_id` lost its line
     number (2026 #1). Before that, the only identical lines are the export's copies: none in
     2012–2019 or 2023–2024, and in 2025 only within the repeated slice. Two
     lines of the same item and quantity on one invoice still differ by line number: 184 such
     pairs in 2024.
   - **What they look like.** They are single lines inside large invoices, not whole invoices
     doubled. INV-957509 has 83 lines, 5 of them doubled. INV-930790 is two `BUY THE BARREL`
     lines of 252 bottles each, which looks like two barrels.
   - **No row-level test.** Once the line number is gone, a real second line and a copy are
     identical in every column. Only the load can tell them apart: the export's extra part
     repeats a whole CSV part. If the loader kept the part file name, staging could drop the
     duplicated part and keep the real repeats.
   - The loss is 21 lines of about 4.5 million.
10. **Rounded money, Nov 2025 – Jan 2026?** Accept. We take what is available.
11. **Why does `sales_dollars` ≠ bottles × retail?** Looked further, on 2026 Feb–Oct:
    - 20,649 of the 22,446 lines (92%) are billed at the item's retail of the previous month.
      All of them are items whose retail changed that month.
    - Those lines are spread over the whole month. About 1 in 9 lines of such an item still gets
      the old price. On days 28–31 nearly all do.
    - Most are on invoices where other lines are billed normally: 10,285 invoices have only one
      such line. Blue Ox (20% of its lines), USDP and Ole Smoky lead.
    - Guess: some orders keep the price in force when they were placed. So `sales_dollars` is
      the amount billed, and `state_bottle_retail` is the current list price.
    - Decision: use `sales_dollars` as the amount, accepted. Feb 2026 lines do not match January
      because January is rounded (Q10).
14. **Which name is right for stores 010830 and 010860?** The latest:
    - 010830 is `VENTURA TOWN MART / VENTURA`. The 8 lines named `GARNER TOWN MART` on
      2026-09-17 belong to the name of store 010831, which has its own address in Garner.
    - 010860 is `PUMP & PANTRY 70 / JOHNSTON`, opened 2026-08-02. The 36 lines named `HY-VEE GAS /
      JOHNSTON` on 2026-08-03 – 08-12 use the name of store 2723 at 5902 Merle Hay Rd.
    - Both look like a name input wrongly, then fixed. Decision: the store dimension takes the
      latest name (type 1). `TEMPORARY & SPECIALTY PACKAGES` is likely a placeholder category in
      the same way (Q2).
15. **Do names change with the volume flips?** No. Only the volume changes, so it is an input fix,
    not a new product:

    | Flip | Items | Name changed | Pack changed |
    |---|---|---|---|
    | 2018-10-01, bottle → pack (2018 #1) | 43 | 10, cosmetic (`WESTERN SON LIME VODKA MINI` → `WESTERN SON LIME MINI`) | 0 |
    | 2019-08-01, pack → bottle (2019 #1) | 107 | 7, cosmetic (`CAPTAIN MORGAN SPICED RUM MINI` ↔ `… ORIGINAL SPICED MINI`) | 3 (Deep Eddy 10,12 → 10) |
    | 2025-09-01, pack → bottle (2025 #2) | 17 | 0 | 0 |

    Every renamed item is still a `MINI`, that is, one bottle. Decision: the product dimension takes
    the latest `bottle_volume_ml` (one bottle). Staging recomputes liters from it as bottles × ml
    / 1000. It does not use `sales_liters` for these items.
16. **Do the 26 group-code items later get a regular code?** Yes, when they sell again. On all
    lines 2023–2026:

    | Group code | Items | Lines | Later on a regular code | Last group-code line |
    |---|---|---|---|---|
    | `1032000` IMPORTED VODKAS | 4 | 72 | 3 (`1032100`) | 2024-03-25 |
    | `1081000` AMERICAN CORDIALS & LIQUEURS | 27 | 61 | 8 (`1081300`, `1081400`) | 2024-01-18 |
    | `1082000` IMPORTED CORDIALS & LIQUEURS | 41 | 234 | 25 (`1082100`) | 2024-03-27 |
    | `1092000` IMPORTED DISTILLED SPIRITS SPECIALTY | 17 | 68 | 8 (`1092100`) | 2024-03-27 |

    - The group code always comes first, and no item goes back to it.
    - The 45 items never sold again are all in the catalog under the regular category
      (`American Cordials & Liqueur` 19, `Imported Cordials & Liqueur` 16, …).
    - Decision: type 1, as Q2. Map each group code to the regular code with the same name for
      lines whose item has no later category.
17. **Was 2022-07-18 a system change?** Likely (human). Decision: category recodes are type 1, as
    Q16. Whether returns before it were left out stays unknown.
18. **What are the $0 lines?** Unknown. Decision: keep them as they are.
19. **Is there a mapping from old to new category codes?** Checked: no.
    - 2,494 items sell on both sides of 2016-08-29 (2016 and Jan–Feb 2017). 2,272 of them (91%)
      keep the same `im_desc`, so they are the same product with a new category.
    - The old codes do not map one to one. Old `1031200` items spread over 4 new codes (77% to
      the top one), old `1022100` over 4 (52%), and old `1011200` over 5 (77%). 56 old codes split
      this way.
    - Decision: the item takes its latest category (type 1), so most old lines get the new
      category through the item. Only items never sold again use the code map of Q21.
    - Some codes keep their number but change meaning: `1011300` TENNESSEE WHISKIES became
      SINGLE BARREL BOURBON WHISKIES (Gentleman Jack moved to `1011400`). `1022100` TEQUILA
      became MIXTO TEQUILA (1800 Añejo moved to `1022200` 100% AGAVE TEQUILA). So an old code
      must never join to the new taxonomy by number.
    - Coverage of the 9,881,662 lines ordered before 2016-08-29 (6,295 items):
      - 3,350 items, 9,375,392 lines (94.9%), sell again later, so they get a new category.
      - 23 items, 4,140 lines, are only in the catalog. They take its category.
      - 2,922 items, 502,130 lines (5.1%), have no new category anywhere. They use the code
        map (Q21).
20. **Absolut gift set at $206 a unit?** Leave it and flag it: staging keeps the amount and sets a
    flag on item 3984's 2013 lines (2013 #2).
21. **Map the old codes for items never sold again?** Yes (human): a seed maps each old code
    to a current code, and staging keeps the old name as the legacy category name (type 3).
    The seed is `seeds/iowa_data_hub/iowa_data_hub__legacy_category_map.csv`, 92 old codes:
    - 81 are mapped by items: the current code that most lines of the old code's items carry
      today. Lines, not items, decide. From Jan 2016 some lines already carry a new code
      with the old code's name, such as Ardbeg 10 as `1012300 IRISH WHISKIES`. By items, old
      `1012300` would map to Single Malt Scotch (35 items, 2,356 lines). By lines it maps to
      Irish Whiskies (32 items, 80,599 lines).
    - 8 are mapped by name (`mapped_by = manual`). For 5 of them, no item sells again
      (`LOW PROOF VODKA` → `AMERICAN VODKAS`). For 3, the item mapping is wrong: `1701100`
      DECANTERS & SPECIALTY PACKAGES → `1701100` TEMPORARY & SPECIALTY PACKAGES, and the
      `101220` Craigellachie lines (2014 #1) → SINGLE MALT SCOTCH.
    - 3 stay unmapped and take the Unknown category: `1501100` HIGH PROOF BEER, and `1081100`
      and `1089290` with no name, 39 lines in all.
    - Review the 6 rows with `share_of_moved_lines` < 0.6, where the old code split. Example:
      `1022100` TEQUILA → `1022100` MIXTO TEQUILA at 0.56; the rest went to 100% AGAVE TEQUILA.

## Questions for the human

12. Store 2687 `HY-VEE FAST & FRESH EXPRESS- BETTENDORF`, 3470 Middle Road, Bettendorf, county
    Scott, has zip `57222` on every line in every year it appears (2019–2026, 2,442 lines).
    - The other 17 Bettendorf stores use `52722`.
    - `57222` is not an Iowa zip, since Iowa zips start `50`–`52`. It is in South Dakota (guess).
    - It is `52722` with the 2nd and 3rd digits swapped.
    - In 2026, no other store has a zip outside Iowa.

    `52722` is never used for this store, in any year, so "take the latest" keeps `57222`.
    `57222` is both its first and latest zip. Can staging replace `57222` with `52722` for store
    2687, or should the zip stay as loaded? (2026 #5)

## Unknown

Nobody can answer these now. The default stands until someone can.

4. Is `inner_pack` the bottles inside one sellable unit? Default: keep it as loaded, with no meaning assumed.
5. What is `scc`? Default: do not use it (products issue #4).
6. What do the `im_desc` codes mean (`DISCO`, `HA`, `BP`, `USE CODE n`, `NO VOR`, `DNO`,
   `Ingredient`)? Default: keep `im_desc` as loaded. Keep the 13 Ingredient items and the magazine
   in the product dimension.
7. Is Old Elk 920301 bottle cost `1250` a typo for `40`, and which value is wrong where case
   cost ≠ bottle cost × pack? Default: keep the values as loaded (products issues #7, #8).
13. Which category is 921635 `TEMPLETON USA 250 STRAIGHT BOURBON WHISKEY` (no category on 26
    lines in 2026)? Default: the Unknown category member (2026 #4).
17. Were returns before 2022-07-18 left out of the data? Default: assume no returns before then.
