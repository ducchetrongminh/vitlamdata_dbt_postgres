# raw_iowa_data_hub.liquor_sales_2019

Profiled 2026-11-07, data as of 2026-11-07 00:03 +07. 2,380,345 rows, ordered
2019-01-02 – 2019-12-31. No row repeats another. One row is one invoice line, as in 2026.

Same as [2020](liquor_sales_2020.md), and through it the later years, except where listed
below. Same method and checks. The 5% sample has 116,983 rows.

## Columns

Only the columns that differ from 2020.

| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `ordered_on` | text → date | | 2019-01-02 – 2019-12-31 | 2 Sundays (305 rows), 8 Saturdays (40,559 rows) |
| `store_no` | text | | | 1,748 stores, 4 digits (2106–9042) |
| `store_name` | text | `HY-VEE OTTUMWA#2` | | 1,766 names (2026 #5) |
| `store_address` … `county_name` | text | | | NULL on 4,764 lines; 3,640 of them in Jul 2019 (2026 #5) |
| `category_code`, `category_name` | text | | | 53 codes; NULL on 2,918 lines (2026 #4) |
| `vendor_number`, `vendor_name` | text | | | 191 vendors, 193 names; NULL on 1 line (2021 #1) |
| `item_no` | text | | | 4,008 items; 975 not in `liquor_products` (2022 #2) |
| `pack` | text → int | | 1 – 48 | |
| `bottle_volume_ml` | text → int | | 20 – 6,000 | pack total for 106 items until 2019-07-31 (#1) |
| `sales_bottles` | text → int | | 1 – 6,750 | |
| `sales_dollars` | text → numeric | | 1.34 – 78,435 | no 13,200-bottle Hy-Vee orders yet |
| `sales_liters` | text → numeric | | 0.02 – 11,812.5 | |
| `sales_gallons` | text → numeric | | 0 – 3,120.53 | |

- Top lines: Costco West Des Moines ordered 6,750 bottles of Kirkland vodka on 2019-07-15.
  The largest amount is 2,988 bottles of Maker's Mark for $78,435.
- `sales_bottles` bins (sample): 1–12 103,173, 13–48 11,457, 49–120 1,607, 121–600 701,
  `>600` 45.

## Issues

| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `bottle_volume_ml` | 106 items switch from the pack's total ml to a bottle's ml on 2019-08-01 | ask (README Q15). Same fix as 2025 #2 | open |
| 2025 #2 | `bottle_volume_ml` | The 2025 #2 items carry the pack total all year, e.g. 48102 at 1,200 | as 2025 #2 | open |
| 2021 #1 | `vendor_number` | NULL on 1 line: `INV-23231800001`, item 984151 `99 ORANGES` | as 2021 #1 | open |
| 2022 #1 | category, returns, stores | Old system all year: no returns, 4-digit stores only | as 2022 #1 | open |
| 2022 #2 | `item_no` | 975 items, 47,897 lines (2.0%), not in the catalog, e.g. 72916 `CAPTAIN MORGAN WATERMELON SMASH` (1,162), 34421 `GREY GOOSE MINI` (1,090) | as 2022 #2 | open |
| 2025 #3 | cost, retail | NULL all year | as 2025 #3 | open |
| 2025 #4 | `invoice_id` | Invoice + line, unique on all 2,380,345 lines | as 2025 #4 | open |
| 2025 #6 | `vendor_name` | 163 renamed on 2019-07-01 | as 2025 #6 | open |
| 2026 #4 | category | NULL on 2,918 lines of 70 items, all year, e.g. 84197 `99 PINEAPPLE MINI` (1,684) | as 2026 #4 | open |
| 2026 #5 | store columns | Location NULL on 4,764 lines. 3,640 are 29 stores in Jul 2019, all with the location on other lines. Some stores change address across such a gap, e.g. 2539 `HIGHWAY 65 SOUTH` → `640 S. OAK` in Apr. Zip `57222` on 194 lines | as 2026 #5 | open |
| 2026 #6 | `im_desc`, `pack` | 4,323 (`item_no`, `im_desc`) pairs for 4,008 items. 129 items change pack or volume, 106 of them #1 | as 2026 #6 | open |
| 2026 #9 | text | Double spaces (sample): `vendor_name` 9,883, `store_address` 10,093, `store_name` 2,702, `im_desc` 1 | as 2026 #9 | open |

No line repeats (2025 #1 does not occur).

### 1. 106 items move to per-bottle volume on 2019-08-01

On 2019-08-01, 106 items change `bottle_volume_ml` to a smaller value that divides the old
one: the pack's total volume becomes one bottle's. Pack does not change. Liters follow the
volume, so these items' liters before August are larger by the bottles per pack.

| item_no | im_desc | pack | ml until 2019-07-31 | ml from 2019-08-01 |
|---|---|---|---|---|
| 10788 | CROWN ROYAL VANILLA MINI | 10 | 300 | 50 |
| 10803 | CROWN ROYAL REGAL APPLE MINI | 10 | 300 | 50 |

Volume changes by month: 106 in Aug, against 1 to 6 in other months. It is the same kind of
change as 2025 #2. The items in 2025 #2 were missed by this one and fixed in 2025.

<details><summary>Query</summary>

```sql
with s as (select item_no, bottle_volume_ml::int as v, min(ordered_on) as first_on,
                  max(ordered_on) as last_on
           from raw_iowa_data_hub.liquor_sales_2019 group by 1, 2),
     c as (select a.item_no, a.v as old_v, b.v as new_v, b.first_on
           from s a join s b on a.item_no = b.item_no and a.last_on < b.first_on and a.v <> b.v)
select substr(first_on, 1, 7) as month, count(*) as changes,
       count(*) filter (where new_v < old_v and old_v % new_v = 0) as to_bottle
from c group by 1 order by 1;
```
</details>
