# Keys and measures of the Iowa liquor order fact: four decisions

Four design questions from building `fact_liquor_order_line` (2026-11-10), one row per invoice
line, about 38M lines over 2012-2026. Each section keeps the situation, the options with their
pros and cons, the decision and what it teaches. Every number comes from a query on the dev
warehouse, on 2012-2013 (about 4.1M lines) unless stated. The design itself is in
[docs/design-external/iowa_data_hub/liquor_order.md](../design-external/iowa_data_hub/liquor_order.md).

## 1. Surrogate keys: md5 text, uuid or bigint?

### Situation
The standards generate every surrogate key with `dbt_utils.generate_surrogate_key`, an md5
hash stored as 32-character text
([standards §1.1](../dimensional-modeling-standards.md#11-dimension-surrogate-keys)). On the
fact, each of the three dimension keys (`store_key`, `product_key`, `vendor_key`) took 33
bytes. Together they were 99 of the 196 bytes of an average line: half the table.

### Options
| Option | Bytes | How |
|---|---|---|
| A. md5 text (the standard) | 33 | `generate_surrogate_key`, as is |
| B. `uuid` | 16 | `md5(...)::uuid`: Postgres stores a uuid as 128 binary bits, so the same hash fits with nothing lost |
| C. `bigint` | 8 | the first 64 bits of the same hash: `('x' \|\| left(md5(...), 16))::bit(64)::bigint` |

- **A**, pros: the standard, readable in a query, no collisions in practice. Cons: the largest,
  and text compares slower than a number in joins.
- **B**, pros: half the size, no information lost, so no added collision risk. Cons: twice the
  size of a bigint.
- **C**, pros: the smallest, and an 8-byte integer is the fastest type to join on. Cons: cutting
  the hash to 64 bits allows collisions. Two of `n` keys collide with odds about n² / 2^65.

### Decision
C, through a new macro `generate_bigint_surrogate_key`, which wraps `dbt_utils`' hash so the
null handling stays the same. The reviewer's reasons: it saves storage, joins faster, and the
data has low cardinality. The largest dimension, product, has 13,463 rows, so a collision has
odds of about 1 in 10^11, and the dimension's primary key constraint would catch one at build.

The fact's table data for 2012-2013 went from 753 MB to 463 MB (−39%). Each dimension key
column holds a "Why we don't follow" note. The change covers the Iowa marts only. The
VitLamData marts keep md5 text.

### Lessons
> **Measure where the bytes go before optimizing.** `avg(pg_column_size(col))` per column
> showed the keys were half of every line, far more than any measure.

> **A collision risk is a number, not a feeling.** Compute n² / 2^bits for the table's real
> size, then decide. 64 bits is plenty for thousands of rows. Over tens of millions, it is
> still small but no longer negligible (see section 4).

## 2. Making `invoice_no` count orders

### Situation
`invoice_no` is a degenerate dimension: the invoice an order line belongs to, with no
dimension table behind it. An analyst counts orders with `count(distinct invoice_no)`. But
after a system change on 2022-07-18, invoice numbers 450000–454720 were issued a second time
to other stores. In 2022, 102,918 invoice numbers stood for 105,374 orders, so the count was
2.3% short.

Example, raw 2022:

| invoice_id | Store | Date | Lines |
|---|---|---|---|
| `INV-45000000001` | 2190 | 2022-07-17 | 1 |
| `INV-45000000002` … `INV-45000000030` | 2667 | 2022-02-23 | 29 |

The full `invoice_id` (invoice + 5-digit line number) never repeats. Only its first part, the
invoice number, does.

### Options
| Option | Value | Bytes a line |
|---|---|---|
| 1. Composite text | `INV-450000/2667/2022` | ~18–27 |
| 2. Mark only the known reuse | `INV-450000` for July, `INV-450000-B` for the Feb 2022 batch | ~8 |
| 3. Bigint hash of number, store and date | `generate_bigint_surrogate_key([...])` | 8 |

- **1**, pros: always one order per value, also if numbers are reused again; readable, so a
  user can still find the invoice. Cons: the largest.
- **2**, pros: no extra size, readable. Cons: only correct for the reuse we know about. Finding
  every reuse needs a scan of all years, and a new reuse would go unnoticed.
- **3**, pros: small and correct. Cons: an opaque number. The naming conventions use `_no` for a
  document number someone can look up, and a hash breaks that.

### Decision
Option 1. Then a second question: which parts are needed? Number + store + date was the first
draft. Checked:

| Range | Numbers | + store | + store + year | + store + date |
|---|---|---|---|---|
| 2012–2013 | 104,558 | 104,558 | 104,558 | 104,558 |
| 2022 | 102,918 | 105,374 | 105,374 | 105,374 |
| 2025-09-01 – 2026 | 148,801 | no number spans two stores or dates | | |

The store alone separates every reused number: each went to a different store. The date splits
nothing further. The reviewer chose number + store + year: the year is a cheap guard in case a
number comes back for the same store in another year, for example if the counter restarts. The
value averages 18 bytes, and the table grew 7% (463 to 497 MB).

### Lessons
> **A degenerate dimension must identify one document.** Test it the way users will use it:
> does `count(distinct ...)` give the number of orders?

> **Find the smallest key the data needs, then add a guard you can explain.** The checks showed
> store was enough; the year was added on purpose, for a stated risk, not out of habit.

> **Prefer a rule that stays right over one that is right today.** Option 2 fixed only the
> reuse we knew about.

## 3. Volume in liters: from the line or from the product?

### Situation
Each sales line has `sales_liters`, from the line's own `bottle_volume_ml`. That volume is not
reliable:
- For some minis, the publisher switched between a bottle's ml and the pack's total ml:
  42 items on 2018-10-01, back on 2019-08-01, and 18 items until 2025-08-29 (profiles 2018 #1,
  2019 #1, 2025 #2). For example, 48102 `HENNESSY VS 100ML` carries 1,200 ml.
- Lines ordered Nov 2025 – Jan 2026 have liters rounded to whole numbers (README Q10).

Profiling had decided that the product dimension takes each item's latest volume (README Q15).
The question was what the fact's liters should follow.

### Options
- **A. Recompute every line** as bottles × the product's latest `bottle_volume_ml` / 1000.
  Pros: one rule; always consistent with `dim_product`; fixes both the flips and the rounding.
  Cons: an item number reused for a different edition with another volume gets today's volume
  on its old lines, and staging can't compute it, because it doesn't know the product's latest
  volume.
- **B. Recompute only the flipped items and the rounded months**, keep `sales_liters`
  elsewhere. Pros: old lines keep the volume they were sold with. Cons: needs a maintained list
  of items and dates, and two rules for one measure.
- **C. Keep `sales_liters`.** Pros: no work. Cons: carries the flips (48102's liters twelve
  times too high) and the rounding.

### Decision
A. A join model, `iowa_data_hub__int_order_line__joined_to_product`, adds `liter_qty` from the
product's volume, catalog first. On 2012 the fact has 18,631,639 liters against 18,755,279 in
the raw `sales_liters` (−0.7%): the difference is the items whose latest volume differs from
the one on their 2012 lines.

### Lessons
> **A derived measure should follow the same type of history as its inputs.** The product is
> type 1 (latest values), so a measure computed from a product attribute follows it.

> **One rule beats a list of exceptions.** An exception list needs upkeep and hides which lines
> were changed.

> **Compare totals after a recompute.** The −0.7% against the source shows the size of the
> change, so it can be explained.

## 4. The line key: made in staging or in the mart?

### Situation
The line key was `order_line_no`: the raw `invoice_id` up to 2025-08-29, and an md5 of the
whole raw row after, because from 2025-09-01 `invoice_id` has no line number and only the
whole row tells lines apart (README Q8). One column held two shapes, a number for some years
and a random text for others. The reviewer proposed one rule: a bigint hash of the whole row
for every year, named `order_line_key`.

Hashing the whole row works for every year. Up to 2025-08-29 the row contains the unique
`invoice_id`, so its hash is unique. The export's repeated rows (README Q9) are identical, so
they hash the same and the dedup still drops them.

The standards make surrogate keys in the mart
([standards §1.1](../dimensional-modeling-standards.md#11-dimension-surrogate-keys)). Could
this one be made there too?

### Options
- **A. In the mart.** Staging passes the raw `invoice_id` through. The dedup becomes
  `select distinct *` per year, and the fact hashes `invoice_id` plus every other column
  (about 15). Pros: follows the standard. Cons: the column list is kept by hand, and a column
  left out could give two lines one key; the columns staging drops (`store_address`,
  `sales_liters`, `sales_gallons`) are no longer covered; `invoice_id` travels through two
  models only to be hashed; and the dedup still needs an identity before the mart.
- **B. In staging.** One hash of the raw row, `generate_bigint_surrogate_key(['filtered::text'])`,
  which the dedup and the fact reuse. Pros: one expression covers every column by
  construction; computed once. Cons: breaks the "keys are made in the mart" rule, so it needs
  a "Why we don't follow" note.

### Decision
B. In 2025, 3,007,599 staging lines gave 2,490,613 distinct keys: the difference, 516,986, is
exactly the export's repeats found in profiling. On the fact, the `unique` and `not_null`
tests on `order_line_key` pass.

The risk accepted: at ~38M lines, two different lines share a 64-bit key with odds of about
1 in 25,000. The fact's `unique` test would catch it, but the dedup runs first and would
silently drop one of the two. The dedup model records this as a known shortcut.

### Lessons
> **Generate a key where its natural key lives.** Here the natural key is the whole raw row,
> and only staging sees it.

> **Follow a standard's reason, not only its words.** "Keys in the mart" exists so key logic
> sits in one place next to the dimension. A key that only staging can compute still sits in
> one place, with the exception written next to it.

> **Know where a failure would be silent.** A collision fails the fact's test loudly, but in the
> dedup it would drop a line quietly. Write that down where the shortcut is taken.
