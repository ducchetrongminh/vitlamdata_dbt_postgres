# raw_iowa_data_hub.liquor_sales_2024

Profiled 2026-11-07, data as of 2026-11-07 00:03 +07. 2,590,975 rows, ordered
2024-01-01 – 2024-12-31. No row repeats another. One row is one invoice line, as in 2026.

Same as [2026](liquor_sales_2026.md) and [2025](liquor_sales_2025.md), except where listed
below. Same method and checks. The 5% sample has 129,630 rows. Publisher docs: dataset
1261; its row count was not read (the page is a JS app).

## Columns

Only the columns that differ from 2026. Every other column is as in 2026.

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `invoice_id` | text | `INV-69661600001`, `RINV-05091100002` | | invoice + line number all year, unique (2025 #4) |
| `ordered_on` | text → date | | 2024-01-01 – 2024-12-31 | 47 Sundays (113,621 rows); 9 Saturdays, 7 of them full order days (5,000–8,200 rows) |
| `store_no` | text | `2633`, `010050` | | 2,162 stores; 6-digit numbers up to 010529 |
| `store_name` | text | `KWIK STOP 3 / WATERLO` | | 2,175 names (2026 #5) |
| `store_address` … `county_name` | text | | | NULL on 422 lines of 7 stores (2026 #5) |
| `category_code` | text | `1082000` | | 48 codes: 4 group codes (#1); no NULL |
| `category_name` | text | `AMERICAN CORDIALS & LIQUEURS` | | the plural names all year (2025 #5) |
| `vendor_number`, `vendor_name` | text | | | 239 vendors, one name each |
| `item_no` | text | | | 5,211 items; no orphans vs `liquor_products` |
| `pack` | text → int | | 1 – 60 | 27 items change pack or volume (2026 #6) |
| `bottle_volume_ml` | text → int | | 20 – 5,250 | pack total for the 2025 #2 items all year, e.g. 48102 at 1,200 |
| `state_bottle_cost`, `state_bottle_retail` | text → numeric | | | NULL on every line (2025 #3) |
| `sales_bottles` | text → int | | -768 – 13,200 | |
| `sales_dollars` | text → numeric | | -8,355.84 – 260,832 | no price to check it against |
| `sales_liters` | text → numeric | | -1,344 – 13,200 | = bottles × volume / 1,000 on every line |
| `sales_gallons` | text → numeric | | -355.04 – 3,487.07 | = bottles × volume / 3,785.41, to 2 decimals |

- Casts: clean, as 2026.
- Top lines: Hy-Vee store 2633 ordered 13,200 bottles of Tito's for $260,832 three times. The
  most negative line is a return of 768 `MEMBERS MARK VODKA`, `RINV-05091100002`.
- `sales_bottles` bins (sample): `<0` 118, 1–12 111,018, 13–48 15,585, 49–120 1,948,
  121–600 905, `>600` 56.

## Issues

2026 #1 (no line key), 2026 #2 and #3 (prices) and 2025 #1 (repeated lines) do not occur:
`invoice_id` is unique, there are no prices, and no row repeats.

| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `category_code` | 4 group codes ending `000` on 75 lines of 26 items, Jan–Mar 2024, each with the name of a `…100` code | clean in staging: type 1, the item's latest category; else the regular code with the same name (README Q16) | decided |
| 2025 #2 | `bottle_volume_ml` | Pack total for the same multi-pack items, all year | as 2025 #2 | open |
| 2025 #3 | cost, retail | NULL all year | as 2025 #3 | open |
| 2025 #4 | `invoice_id` | Invoice + line, unique on all 2,590,975 lines | as 2025 #4 | open |
| 2025 #5 | `category_name` | The old plural names all year | as 2025 #5 | open |
| 2026 #4 | category | 151 extra (`item_no`, `category_code`) pairs, including #1 | as 2026 #4 | open |
| 2026 #5 | store columns | Location NULL on 422 lines of 7 stores: 010206 from 2024-09-04 (it has one before). Zip `57222` on 287 lines. Typos: 4265 `/ WATERLO` beside `/ WATERLOO` Jun–Dec, 010450 `WIKES` then `WILKES`. 010395 address `303` → `1303 4TH ST SW` | as 2026 #5 | open |
| 2026 #6 | `im_desc`, `pack` | 5,337 (`item_no`, `im_desc`) pairs for 5,211 items. 27 items change pack or volume, mostly minis between 10 and 12 a case | as 2026 #6 | open |
| 2026 #7 | returns | 2,977 `RINV-` lines, 9 positive; 15 `INV-` lines negative | as 2026 #7 | open |
| 2026 #8 | `store_no` | as 2026 | as 2026 #8 | open |
| 2026 #9 | text | Double spaces (sample): `vendor_name` 23,136, `store_address` 5,973, `store_name` 2,026, `im_desc` 166 | as 2026 #9 | open |

### 1. Four group-level category codes

Each category code ends `100`, `200`, … except 4 that end `000`. They are used only from
2024-01-02 to 2024-03-27, on 75 lines of 26 items, mostly new specialty imports (item numbers
9xxxxx). Each carries the same name as a regular code, so a name maps to two codes:

| category_code | category_name | Lines | Same name as |
|---|---|---|---|
| 1032000 | `IMPORTED VODKAS` | 7 | 1032100 |
| 1081000 | `AMERICAN CORDIALS & LIQUEURS` | 1 | 1081300 |
| 1082000 | `IMPORTED CORDIALS & LIQUEURS` | 61 | 1082100 |
| 1092000 | `IMPORTED DISTILLED SPIRITS SPECIALTY` | 6 | 1092100 |

Guess: the group code was a placeholder until the item got its real category. Keyed on
code, these are 4 extra categories with duplicate names. `1071000 COCKTAILS/RTD` and
`1901000 SPECIAL ORDER ITEMS` also end `000` but are regular codes used all year.

<details><summary>Query</summary>

```sql
select category_code, category_name, item_no, im_desc, count(*), min(ordered_on), max(ordered_on)
from raw_iowa_data_hub.liquor_sales_2024
where category_code like '%000' and category_code not in ('1071000', '1901000')
group by 1, 2, 3, 4 order by 1;
```
</details>
