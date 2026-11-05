# iowa_liquor

Iowa liquor product catalog and sales, published by the Iowa Alcoholic Beverages
Division on the Iowa Data Hub (data.iowa.gov, CC BY 4.0). Iowa is a control state:
the state buys from vendors and sells to licensed retailers, so the catalog carries
state cost and state retail prices.

Loaded by `ingestion/iowa_liquor/pipeline.py` (dlt, destination Postgres, schema
`raw_iowa_liquor`). It downloads each dataset's CSV zip export. Every column lands as
text; an empty cell lands as NULL.

- `products` (dataset 1029): the current catalog, a monthly snapshot. Each load
  replaces the whole table (`write_disposition="replace"`), so there is no history.
- `sales_<year>` (datasets 1249–1263): one table per year, each replaced whole when it
  loads. Past years load once; the latest year reloads every run.

The publisher's dataset page (https://data.iowa.gov/catalog/dataset/1029) says only
"a list of liquor products maintained by the Iowa Alcoholic Beverages Division". Its
column definitions sit in a JS tab that could not be fetched, so column meanings here
come from the data. Who enters products and how categories are assigned is unknown
(questions below).

| Table | Rows | Grain | Profile |
|---|---|---|---|
| `products` | 14,040 | One item per category it is listed under (`item_no`, `category_name`). 11,668 items. | [products.md](products.md) |

Only `products` is profiled here. The `sales_*` tables were used only to check the
join below.

## Relationships

- `sales_2026.item_no` → `products.item_no`: many-to-one by item, but `products` has
  up to 3 rows per item (see products issue 1), so join on the deduplicated item.
  0 orphans: all 4,792 items and 2,029,764 rows in `sales_2026` match a product.
  6,876 of 11,668 products have no 2026 sales. Older years not checked.
- `sales_2026.vendor_number` vs `products.vendor_no`: differs for 90 items. Guess:
  the vendor changed and the catalog holds only the current one.
- `sales_2026.category_name` is the item's base category (e.g. "STRAIGHT BOURBON
  WHISKIES"), upper case, with a `category_code`. `products` has no category code.

## Questions for the human

1. Products have 2–3 categories (2,354 items). The extra row is almost always
   "Temporary & Specialty Packages" or "Iowa Spirits Manufacturers", and sales never
   use those two for such items. Are these two tags (gift pack, made in Iowa) rather
   than categories? Should staging keep one row per item with flags? (products #1)
2. What unit is `age`? Most items match "NN YR" in the name, but some are clearly
   months (products #3).
3. What do the description markers mean: "DISCO" (685 items, discontinued?),
   "USE CODE nnnnnn" (355, replaced by another item?), and the prefixes "HA" (597),
   "BP" (108), "CM" (58)? Guess: discontinued, superseded, high-allocation, barrel
   pick. Any of them worth a column?
4. `list_on` is after the report date for 110 rows, yet 21 of those items already sold
   in 2026. Is `list_on` the original listing date, or the latest re-listing?
   (products #7)
5. Which is right when `state_case_cost` is not `state_bottle_cost × pack`?
   (products #8)
