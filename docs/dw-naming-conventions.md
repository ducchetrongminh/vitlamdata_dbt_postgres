# Data Warehouse Naming Conventions

Naming rules for models, columns, folders, and schemas in this dbt project. Read before designing or building a model. For layer rules, see [dbt Layers Conventions](dbt-layers-conventions.md); for schema names, see [Architecture §4](architecture.md#4-warehouse-layout).

## Table of Contents

1. [General Naming Principles](#1-general-naming-principles)
   1. [Descriptive over short](#11-descriptive-over-short)
   2. [Abbreviations avoided](#12-abbreviations-avoided)
   3. [snake_case everywhere](#13-snake_case-everywhere)
   4. [Business language, not source jargon](#14-business-language-not-source-jargon)
   5. [Consistency across models](#15-consistency-across-models)
2. [Abbreviations](#2-abbreviations)
   1. [Approved abbreviations](#21-approved-abbreviations)
   2. [Banned abbreviations](#22-banned-abbreviations)
3. [Model File Naming](#3-model-file-naming)
   1. [Layer prefix required](#31-layer-prefix-required)
   2. [Singular nouns for entity names](#32-singular-nouns-for-entity-names)
   3. [Staging naming](#33-staging-naming)
   4. [Intermediate naming](#34-intermediate-naming)
4. [Column Naming](#4-column-naming)
   1. [Key column suffixes](#41-key-column-suffixes)
   2. [Role-playing foreign key naming](#42-role-playing-foreign-key-naming)
   3. [Degenerate dimension suffix](#43-degenerate-dimension-suffix)
   4. [Entity prefix on common column names](#44-entity-prefix-on-common-column-names)
   5. [Boolean and indicator columns](#45-boolean-and-indicator-columns)
   6. [Date and time suffixes](#46-date-and-time-suffixes)
   7. [Standard fact prefixes and suffixes](#47-standard-fact-prefixes-and-suffixes)

---

## 1. General Naming Principles

### 1.1 Descriptive over short
Use a long, self-explanatory name over a short, fuzzy one — for models, columns, CTEs, and aliases.

#### Definition
A descriptive name spells out what an entity or column represents in full words. A fuzzy name shortens or truncates it, trading clarity for keystrokes.

#### Pros
- Readable without opening the model or asking a teammate what a column means
- New Analytics Engineers ramp up faster — the name teaches the schema
- Reduces misuse — an ambiguous name invites the wrong join key or wrong aggregation

#### Cons
- Longer identifiers to type and to fit in query output columns

#### Decision
Always prefer the fully descriptive name. Length is not a cost worth optimizing for; ambiguity is. Only shorten using an approved abbreviation from [Abbreviations](#2-abbreviations) — never invent a new shorthand.

```sql
-- Yes: RFM outcome columns spell out what each metric and segment means
select
    customer_id,
    recency_score,
    frequency_score,
    monetary_score,
    recency_percentile,
    frequency_percentile,
    monetary_percentile,
    customer_rfm_segment
from {{ ref('int_customer_scored_rfm') }}
```

```sql
-- No: short but fuzzy — reader must guess what recency/frequency/monetary stand for
select
    customer_id,
    recency,
    frequency,
    monetary,
    rfm_segment
from {{ ref('int_customer_scored_rfm') }}
```

Same for table aliases: use the shortest name that still says what the table is.

```sql
-- Yes: each alias reads as the entity it holds
select
    header.order_no,
    line.line_no,
    line.product_id
from {{ ref('stg_shop__order_header') }} as header
join {{ ref('stg_shop__order_line') }} as line on header.order_no = line.order_no
```

```sql
-- No: single-letter aliases — reader must scroll to the from clause to decode every column
select
    o.order_no,
    l.line_no,
    l.product_id
from {{ ref('stg_shop__order_header') }} o
join {{ ref('stg_shop__order_line') }} l on o.order_no = l.order_no
```

### 1.2 Abbreviations avoided

Never invent an abbreviation on the fly. If a term needs shortening, propose it for the [Abbreviations](#2-abbreviations) list first; only use abbreviations that already appear there.

```sql
-- Yes: id and amt are on the approved list
select
    customer_id,
    order_amt
from {{ ref('stg_shop__order') }}
```

```sql
-- No: cust and dt are not on the approved list — invented shorthand carried over out of habit
select
    cust_id,
    order_dt
from {{ ref('stg_shop__order') }}
```

### 1.3 snake_case everywhere
Use lower_snake_case for every model, column, CTE, and alias.

#### Pros
- Matches SQL's case-insensitive identifier convention — no quoting needed to preserve casing
- Consistent with dbt community convention, so packages and generated docs read uniformly

#### Cons
- Source systems delivering camelCase or PascalCase columns need renaming at the staging layer

#### Decision
Rename every column to lower_snake_case at the staging layer, regardless of source casing. Never carry camelCase or PascalCase past `01_staging`.

```sql
-- Yes: stg_crm__customer.sql renames source camelCase to snake_case
select
    "customerId" as customer_id,                          -- quoted: Postgres folds unquoted names to lowercase
    "customerLifetimeValue" as customer_lifetime_value
from {{ source('crm', 'customer') }}
```

### 1.4 Business language, not source jargon

Source systems often expose columns named after internal implementation details — a table code, a legacy field name, a system-specific abbreviation — that mean nothing to a business user reading a report.

Rename every source column to its business meaning at the staging layer. Retain the original source field name only as a code comment or in the column's `description` in `_<source>__sources.yml`, never as the column name past `01_staging`.

```sql
-- Yes: stg_wordpress__course.sql renames WordPress's generic post columns to their business meaning
select
    post_id as course_id,
    post_title as course_title,
    post_excerpt as course_summary
from {{ ref('base_wordpress__post') }}
where post_type = 'courses'
```


### 1.5 Consistency across models

Before naming a column for a business concept, search existing models for how it's already named and reuse that name. Never introduce a second name for a concept another model has already named.

This also directly enables [Dimensional Modeling Standards, Conformed Dimensions](dimensional-modeling-standards.md#18-conformed-dimensions) and [Dimensional Modeling Standards, Conformed Facts](dimensional-modeling-standards.md#25-conformed-facts), which require identical names as a precondition.

---

## 2. Abbreviations

### 2.1 Approved abbreviations

Use only the abbreviations below. To add a new one, propose it in a PR that updates this list, before using it in a model.

**Generic**

| Abbreviation | Meaning |
|---|---|
| `id` | identifier |
| `amt` | amount |
| `qty` | quantity |
| `pct` | percent |
| `no` | number |

**Time period**

| Abbreviation | Meaning |
|---|---|
| `mtd` | month-to-date |
| `ytd` | year-to-date |
| `fy` | fiscal year |
| `ly` | last year (comparison column) |
| `ty` | this year (comparison column) |
| `wk` | week |

**Domain/system-specific** — full form is itself jargon or a proper system name

None yet.

**Model layer prefixes** — see [Model File Naming](#3-model-file-naming) for full rules on where each applies

| Prefix | Meaning |
|---|---|
| `base_` | base (staging, when one source table holds several entities) |
| `stg_` | staging |
| `int_` | intermediate |
| `dim_` | dimension |
| `fact_` | fact |
| `snap_` | snapshot |

### 2.2 Banned abbreviations
Never use these; spell the full word instead.

#### Definition
A banned abbreviation is common shorthand for a term that has a short, plain-English word available (`cust` for `customer`) — unlike the approved list, spelling it out costs nothing.

#### Decision
Never use these in models or columns; spell the full word instead.

| Banned | Use instead |
|---|---|
| `cat` | `category` |
| `disc` | `discount` |
| `prod` | `product` |
| `sub` | `subcategory` |
| `tran` / `txn` | `transaction` |

---

## 3. Model File Naming

### 3.1 Layer prefix required
Prefix every model file with its layer: `base_`, `stg_`, `int_`, `dim_`, or `fact_`. Snapshots use `snap_<source>__<table>`, named after the raw table they copy, in `snapshots/<source>/`.

#### Definition
The layer prefix identifies which stage of the dbt DAG a model belongs to.

#### Pros
- The model's role is visible in every `ref()` call, SQL editor tab, and DAG node — no need to check the folder
- Prevents accidental cross-layer confusion (e.g., referencing a staging model where a mart is expected)

#### Decision
Every model file must start with its layer prefix, matching the folder it lives in: 
- `base_` in `01_staging/<source>/base/`
- `stg_` in `01_staging`
- `int_` in `02_intermediate`
- `dim_`/`fact_` in `03_mart`

Marts use `fact_`, not dbt Labs' `fct_`.

```
-- Yes:
models/01_staging/wordpress/stg_wordpress__order_line.sql
models/02_intermediate/sales/int_order_line_joined_to_header.sql
models/03_mart/sales/dim_course.sql
models/03_mart/sales/fact_order_line.sql
```

```
-- No: no layer prefix — role isn't visible from the file name alone
models/03_mart/sales/sales_orders.sql
```

### 3.2 Singular nouns for entity names
Name a model after the entity it represents using the singular noun, across every layer.

#### Definition
An entity name is the noun portion of a model name after its layer prefix — `customer` in `stg_crm__customer`, `customer` in `dim_customer`. Singular names what one row is: one customer, one order line.

#### Pros
- Matches Kimball and the [Dimensional Modeling Standards](dimensional-modeling-standards.md) (`dim_product`, `fact_order_line`, `dim_date`)
- Model name matches the column prefix from [4.4](#44-entity-prefix-on-common-column-names): `dim_customer` holds `customer_key`, `customer_id`, `customer_name`
- No irregular plurals to look up (`category`/`categories`, `person`/`people`, `status`/`statuses`) and no exception for uncountable nouns (`inventory`, `equipment`)
- A fact table is named after its grain, which is one row: `fact_order_line` — one row per order line

#### Cons
- Departs from the [dbt best practices guide](https://docs.getdbt.com/best-practices/how-we-structure/2-staging) and most dbt community examples, which use plural
- Some intermediate names read less naturally (`int_payment_pivoted_to_order` vs. plural `int_payments_pivoted_to_orders`)

#### Decision
Use the singular noun for the entity portion of a model name in every layer: `stg_`, `int_`, `dim_`, and `fact_`. Raw source table names keep their own spelling in `_<source>__sources.yml` and `source()`, since they must match the database — staging renames them.

```
-- Yes:
stg_crm__customer.sql
dim_customer.sql
fact_order.sql
```

```
-- No: plural entity name
stg_crm__customers.sql
dim_customers.sql
fact_orders.sql
```

### 3.3 Staging naming
Name staging models `stg_<source>__<entity>`, one model per source table.

#### Definition
The double underscore (`__`) separates the source system name from the entity name, disambiguating names where either part could itself contain an underscore (e.g., `stg_google_analytics__campaign` vs. the ambiguous `stg_google_analytics_campaign`).

#### Pros
- Source system is visible in the name without opening the model
- One-to-one mapping to source tables keeps staging models simple and mechanical — easy to audit against `sources.yml`
- Grouping staging folders by source system (not by loader or business function) keeps a source's models together regardless of which teams consume them
- A clear, business-friendly entity name at the staging layer means every downstream model inherits it via `ref()` — no need to re-translate the source's naming further up the DAG

#### Cons
- Source system name changes (e.g., a system migration) require renaming every staging model and downstream `ref()`

#### Decision
Name every staging model `stg_<source>__<entity>`, using the singular entity noun from [3.2](#32-singular-nouns-for-entity-names). The entity portion must be clear and business-friendly, not the raw source table name — apply [1.1](#11-descriptive-over-short) and [1.4](#14-business-language-not-source-jargon) at the model name itself, not just its columns. Build exactly one staging model per source table — or, when one table holds several entities, one base model `base_<source>__<entity>` in a `base/` subfolder and one staging model per entity on top of it (see [dbt Layers Conventions, Staging structural constraints](dbt-layers-conventions.md#21-staging-structural-constraints)). Group staging models into subfolders by source system, e.g. `01_staging/wordpress/`, `01_staging/metabase/` — never by loader (dlt) or by business function (sales, marketing). Each folder holds `_<source>__sources.yml` and `_<source>__models.yml`.

```
-- Yes:
models/01_staging/wordpress/stg_wordpress__order_line.sql
models/01_staging/metabase/stg_metabase__dashboard.sql
models/01_staging/wordpress/base/base_wordpress__post.sql   -- wp_posts, every post type
models/01_staging/wordpress/stg_wordpress__course.sql       -- reads base_wordpress__post
```

```
-- No: raw source table name (wp_tutor_order_items) carried straight into the model name
models/01_staging/wordpress/stg_wordpress__wp_tutor_order_items.sql
```

### 3.4 Intermediate naming
Name intermediate models after the main transformation they perform: `int_<entity>_<verb_phrase>`.

#### Definition
An intermediate model has one purpose — a pivot, a join, a fan-out, an aggregation — on its way from staging to a mart. It may take several CTE steps to get there (`int_order_line_joined_to_header` joins, then allocates the header discount). The verb phrase names the main transformation, not just the entity being transformed.

#### Pros
- A reader understands what the model does from its name alone, without opening the SQL
- Distinguishes multiple intermediate models over the same entity by what each one does to it (`int_order_joined_to_payment` vs. `int_order_aggregated_to_customer`)

#### Cons
- Verb-phrase names run longer than a bare entity name

#### Decision
Name every intermediate model `int_<entity>_<verb_phrase>`, where the verb phrase states its main transformation in plain English (`pivoted`, `joined`, `aggregated_to_<grain>`). Supporting steps don't need their own model or a place in the name. Split a model only when its steps serve different purposes, or another model needs one step on its own. Drop the source-system double underscore at this layer — intermediate models are business-conformed, not source-specific. Group them into subfolders by business domain (`02_intermediate/sales/`), not into the file name.

```
-- Yes:
int_payment_pivoted_to_order.sql
int_order_aggregated_to_customer.sql
```

```
-- No: verb missing — model does an aggregation, but the name doesn't say so
int_order_customer.sql
```

---

## 4. Column Naming

### 4.1 Key column suffixes
Suffix warehouse-generated surrogate keys with `_key`; suffix natural/business keys carried from source with `_id` or `_code`.

#### Definition
A surrogate key is a value generated during the ETL load (sequence or hash) with no meaning outside the warehouse. A natural key is an identifier that exists in the source system itself and carries business meaning there.

#### Pros
- Reader sees at a glance whether a key is safe to join across warehouse tables only (`_key`) or matches a source-system identifier usable for external reconciliation (`_id`/`_code`)
- Prevents accidentally joining a DW surrogate key to a source system's natural key for the same entity
- Signals which columns stay stable across a source-system migration (`_key`) versus which don't (`_id`/`_code`, tied to the legacy source)

#### Cons
- Two suffix families for conceptually similar "key" columns adds a category modelers must classify correctly

#### Decision
Suffix every warehouse-generated surrogate key with `_key`. Suffix every natural/business key sourced verbatim from an operational system with `_id` (numeric or opaque identifier) or `_code` (short alphanumeric code). Never use `_key` for a value that also exists, unchanged, in the source system — that's a natural key.

Exception: the date dimension is keyed by the date value itself, not suffixed `_key` (e.g. `order_date`, `ship_date`) — see [Dimensional Modeling Standards, Dimension Surrogate Keys](dimensional-modeling-standards.md#11-dimension-surrogate-keys).

```sql
-- Yes: surrogate key and natural keys suffixed by origin
select
    customer_key,     -- DW-generated surrogate key
    customer_id,      -- natural key from the source
    coupon_code       -- natural key, alphanumeric code from source
from {{ ref('dim_customer') }}
```

```sql
-- No: CRM's natural id mislabeled as a DW surrogate key
select
    customer_key,       -- correct: DW-generated surrogate key
    crm_customer_key     -- wrong: this is CRM's natural id — should be crm_customer_id
from {{ ref('dim_customer') }}
```

### 4.2 Role-playing foreign key naming
When a fact table has multiple foreign keys to the same conformed dimension, prefix each with a passive-verb phrase naming its role.

#### Definition
See [Dimensional Modeling Standards, Role playing dimension](dimensional-modeling-standards.md#17-role-playing-dimension).

#### Pros
- Disambiguates which role each foreign key represents without opening the fact table's join logic or model docs
- The passive-verb phrase reads naturally as a sentence — "the order was created by this employee"

#### Cons
- Longer column names than a plain `<entity>_key`

#### Decision
When a fact table references the same dimension in more than one role, name each foreign key `<passive_verb>_by_<entity>_key`. Never point two foreign keys at the same conformed dimension without a role prefix.

Exception: a date role is named `<role>_date` (`order_date`, `ship_date`), since the date dimension is keyed by the date itself — see [4.1](#41-key-column-suffixes).

```sql
-- Yes: each foreign key to dim_employee names its role
select
    order_key,
    created_by_employee_key,   -- employee who created the order
    updated_by_employee_key,   -- employee who last updated the order
    approved_by_employee_key   -- employee who approved the order
from {{ ref('fact_order') }}
```

```sql
-- No: role or foreign key is ambiguous
select
    order_key,
    created_employee,
    updated_by
from {{ ref('fact_order') }}
```

### 4.3 Degenerate dimension suffix
Suffix a degenerate dimension column with `_no`.

#### Definition
A degenerate dimension is a source-system identifier (an order number, invoice number, document number) carried directly on a fact table with no corresponding dimension table, because it has no attributes beyond the identifier itself.

#### Decision
Suffix every degenerate dimension column with `_no`, not `_id` or `_code` — `_no` marks it as a fact-table-resident identifier with no dimension table behind it.

```sql
-- Yes: document_no is a degenerate dimension, no dim_document table exists
select
    order_key,
    document_no,
    order_amt
from {{ ref('fact_order') }}
```

```sql
-- No: _id implies a dimension table backs this identifier, but none exists
select
    order_key,
    document_id,
    order_amt
from {{ ref('fact_order') }}
```

### 4.4 Entity prefix on common column names
Never use a bare common column name — always prefix it with the entity it belongs to.

#### Definition
A common column name (`key`, `id`, `code`, `name`, `status`) is a generic attribute name that recurs across many entities, ambiguous the moment columns from more than one entity sit in the same model or report.

#### Pros
- Stays unambiguous once multiple entities are joined into one model or report — `customer_id`, `product_id`, and `order_id` never collide
- Matches [Consistency across models](#15-consistency-across-models) — the same entity's column keeps the same name in every model it appears in via `ref()`
- Downstream BI tools and consumers can search or autocomplete a column by entity name, not a generic term

#### Cons
- More typing than the bare generic name
- Feels redundant in a model scoped to a single entity, where ambiguity can't yet occur

#### Decision
Never name a column `key`, `id`, `code`, `name`, or `status` on its own. Always prefix it with the entity it belongs to: `customer_id`, `customer_name`, `customer_status`, `customer_key`, `coupon_code`. Apply this even in single-entity staging models — intermediate and mart models join multiple entities together and inherit the column name via `ref()`.

```sql
-- Yes: every common column is prefixed with its entity
select
    id as customer_id,
    name as customer_name,
    status as customer_status
```

```sql
-- No: bare common names collide the moment this joins another entity
select
    id,
    name,
    status
```

### 4.5 Boolean and indicator columns
Name every flag or boolean as a textual attribute: `is_`/`has_` prefix for an adjective state, `_indicator` suffix for a categorical state.

#### Definition
See [Dimensional Modeling Standards, Flags and Indicators as Textual Attributes](dimensional-modeling-standards.md#14-flags-and-indicators-as-textual-attributes) — every flag or boolean is published as a self-describing word, not a raw code (`Y`/`N`, `1`/`0`, `true`/`false`).

#### Pros
- Filters and group-bys read naturally without a lookup table
- The column name alone signals which value pattern to expect — adjective pair or category word

#### Cons
- Two related patterns (`is_`/`has_` vs `_indicator`) is one more distinction modelers must classify correctly

#### Decision
Use `is_`/`has_` prefix when the column reads as a yes/no adjective about the row; publish its values as a positive/negative word pair (`Active`/`Not Active`), never `Y`/`N`, `1`/`0`, or `true`/`false`. Use `_indicator` suffix when the value reads better as a category noun than an adjective (`holiday_indicator` with `Holiday`/`Non-holiday`).

```sql
-- Yes: is_ carries a positive/negative word pair, _indicator carries a category word
select
    case when active is true then 'Active' else 'Not Active' end as is_active,
    case when is_holiday is true then 'Holiday' else 'Non-holiday' end as holiday_indicator,
    case when is_holiday is true then 'Holiday' else 'Not Holiday' end as is_holiday, -- either ways are fine, as long as naming is consistent
```

### 4.6 Date and time suffixes
Suffix a date-only column with `_date`, a time-only column with `_time`, and a full date-plus-time column with `_at`.

#### Pros
- Reader knows a column's grain and data type before querying it — no need to inspect the schema to know whether truncating to a day is safe
- Prevents comparing or joining a date-only column against a timestamp column without an explicit cast

#### Decision
Suffix every date-only column with `_date`, every time-only column with `_time`, and every combined date-plus-time column with `_at`. Never use `_date` for a column that also carries a time component.

A date or time column with no timezone suffix is in Vietnam time (`Asia/Ho_Chi_Minh`): `_at`, `_date`, and `_time`. A value in another timezone adds the timezone as a suffix — `_at_<timezone>`, `_date_<timezone>`, `_time_<timezone>` — in practice only `_utc`. Store `_at` as `timestamp` (without time zone), so the suffix states what the wall-clock value means. Convert in staging, e.g. `created_at_utc at time zone 'UTC' at time zone 'Asia/Ho_Chi_Minh' as created_at`.

```sql
-- Yes: suffix matches what each column actually stores
select
    order_id,
    order_date,         -- date only, Vietnam time
    order_time,         -- time only, Vietnam time
    order_at,           -- date and time together, Vietnam time
    order_at_utc,       -- same moment in UTC
    order_date_utc      -- date of order_at_utc
from {{ ref('stg_shop__order') }}
```

### 4.7 Standard fact prefixes and suffixes
Suffix a fact measure with a standard term for its unit; prefix it with a standard term when it is a variant of a value.

#### Definition
A fact measure's prefix states which variant of a value it is (actual, planned, allocated); its suffix states the unit the value is expressed in (quantity, amount, percent).

#### Pros
- Two fact columns for the same business concept (`target_revenue_amt` vs `actual_revenue_amt`) sort and scan together, and their difference is legible from the name alone
- The suffix rules out unit-mismatched arithmetic at a glance — no need to check the column's data type before summing or averaging it
- New measures reuse an existing vocabulary instead of every model inventing its own

#### Cons
- A measure that isn't a clean fit for any standard prefix or suffix still needs one assigned, forcing a judgment call

#### Decision
Suffix every fact measure with the standard term for its unit. When a measure is a variant (budget, actual, allocated, gross, net…), prefix it with the standard term for that variant. Only add a new prefix or suffix to these tables in a PR that updates this doc.

**Prefixes**

| Prefix | Meaning |
|---|---|
| `budget_` | value from the approved budget |
| `target_` | value being aimed for |
| `forecast_` | value predicted for a future period |
| `actual_` | value actually realized, in the context of budget, target, or forecast |
| `allocated_` | value allocated down to line level from the header facts |
| `gross_` | the total amount of something, value before deductions |
| `net_` | what remains from the whole after deductions |

**Suffixes**

| Suffix | Meaning |
|---|---|
| `_qty` | quantity |
| `_amt` | amount |
| `_unit_price` | price per unit |
| `_pct` | percent |
| `_rate` | a ratio expressed per unit of another measure |
| `_count` | a count of discrete items |

**Currency suffixes** — which currency an amount is in

| Suffix | Meaning |
|---|---|
| `_amt` | amount in accounting currency (VND) |
| `_amt_in_<currency>` | amount converted to one specific named currency, e.g. `net_amt_in_usd` |
| `_amt_in_currency` | amount in the currency identified by the row's `currency_key` — the fact table must carry a `currency_key` column |

```sql
-- Yes: prefix states the value's kind, suffix states its unit and currency
select
    product_key,
    currency_key,
    actual_revenue_amt,
    target_revenue_amt,
    net_sales_qty,
    net_amt_in_usd,
    purchased_amt_in_currency
from {{ ref('fact_sales') }}
```

```sql
-- No: no prefix to distinguish actual from target, no suffix to state the unit
select
    product_key,
    revenue,
    revenue_target,
    sales
from {{ ref('fact_sales') }}
```

