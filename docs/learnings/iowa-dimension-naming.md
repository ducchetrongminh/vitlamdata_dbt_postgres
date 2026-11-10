# Product or liquor product? Naming dimensions when the scope widens

A naming question from building the Iowa liquor order mart (2026-11-10): once the source
covers more than liquor, should its dimensions say "liquor" in their names? The decision was
to keep the short names, `dim_product` and `dim_vendor`. This record keeps the situation, the
reasoning on both sides and when to revisit it.

## 1. The situation

The source started as `iowa_liquor`. Liquor is only one dataset on the Iowa Data Hub
(data.iowa.gov), so the source was renamed `iowa_data_hub`, after the system we extract from.
Its tables got a dataset prefix: `liquor_products`, `liquor_sales_<year>` (see
[iowa-ingest-performance.md](iowa-ingest-performance.md#1-a-rename-forces-a-full-reload)).

The first mart built on it models one business process, liquor orders:

| Table | Holds |
|---|---|
| `fact_liquor_order_line` | one row per invoice line of a store's order from the state |
| `dim_store` | the licensed stores that order |
| `dim_product` | the liquor items (catalog and sales lines) |
| `dim_vendor` | the companies whose liquor the state sells |

All four live in schema `mart_ext_iowa_data_hub`, the mart schema of this external source
([CLAUDE.md, External datasets](../../CLAUDE.md#external-datasets)). Its bus matrix is
[docs/design-external/iowa_data_hub/_bus_matrix.md](../design-external/iowa_data_hub/_bus_matrix.md).

## 2. The question

The source name widened from liquor to the whole data hub. The fact says "liquor", but the
dimensions do not. Should `dim_product` and `dim_vendor` become `dim_liquor_product` and
`dim_liquor_vendor`, so a reader can't mistake them for products of some other Iowa dataset?

The reviewer felt both pulls: the rename looked like over-engineering, since no other Iowa
dataset is planned, and if one came we could add its product then. But it also made the
tables clearer today.

## 3. The options

### A. Rename now: `dim_liquor_product`, `dim_liquor_vendor`

Pros:
- The name alone says what is inside, with no need to read the description or the schema.
- No rename later, so no Metabase question or downstream query breaks when a second dataset
  arrives.

Cons:
- It names the dimension after one fact's subject. In dimensional modeling, a dimension is
  named after the entity it describes, so other facts can reuse it (conformed dimensions).
  If a later fact also needs these products, for example liquor inventory or price changes,
  the "liquor" prefix adds nothing, and on a non-liquor product it would be wrong.
- It pays now for a dataset that may never come (YAGNI).
- It is inconsistent unless `dim_store` gets a prefix too. Stores are liquor licensees, so the
  same argument applies there.

### B. Keep `dim_product`, `dim_vendor` (chosen)

Pros:
- The schema `mart_ext_iowa_data_hub` already scopes the tables to this source, and the fact
  name `fact_liquor_order_line` already names the business process. The process belongs in
  the fact name, not in each dimension's name.
- Short names match the other dimensions (`dim_store`, and later `dim_date`).
- The dimension stays open to reuse by another fact of the same bus.

Cons:
- A reader of the bare table name can't tell the products are liquor. The description has to
  say so.
- If a second dataset brings a different kind of product, one of the two must take a
  qualified name, and renaming an existing table breaks the queries built on it.

## 4. The decision

Keep `dim_product` and `dim_vendor`. Make the clarity cheap instead: the model descriptions
say "liquor".

When another Iowa dataset arrives, ask one question: are its products the same entity?

- **Same entity** (the same items, the same codes): widen `dim_product` to hold them. The
  short name was right.
- **A different entity** (for example tobacco permits or lottery games): give the new
  dimension the qualified name (`dim_tobacco_product`). Rename the liquor one only if the two
  could be confused, and plan that rename together with whoever uses the tables.

Renaming later touches about three models, their ymls and the design docs, plus any saved
Metabase questions. Since this is a practice dataset, that cost is acceptable.

## 5. Lessons

> **Name a dimension after the entity, not after the fact that first uses it.** The fact
> carries the business process (`fact_liquor_order_line`). The dimension carries the thing
> (`dim_product`), so the next fact can reuse it.

> **Let the schema carry the scope.** A source schema (`mart_ext_iowa_data_hub`) already says
> where a table comes from. Repeating the scope in every table name adds length, not meaning.

> **Weigh a rename now against a rename later.** A rename now costs little but is paid for
> certain. A rename later costs more, but is paid only if the second dataset comes. With no
> second dataset planned, wait.

> **Write the trigger down.** A deferred decision needs a stated condition for revisiting it
> ("when another dataset brings products, ask whether they are the same entity"), or nobody
> will know it was deferred.
