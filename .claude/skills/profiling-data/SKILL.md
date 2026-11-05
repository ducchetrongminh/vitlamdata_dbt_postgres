---
name: profiling-data
description: Use when exploring a new source, schema or raw table before modeling it, when asked to profile data or check data quality, or when staging needs to know a table's grain, types and value problems.
---

# Profiling data

## Overview

Understand the data before modeling it, and leave a record a human reviews in one
read. The record is a list of conclusions and issues, each with its evidence and its
query. It is not a log of every check run.

## Process

1. **Understand the source.**
   - Read the loader and its config: how each table is loaded (replace, merge,
     append), types as loaded.
   - List schemas, tables and columns.
   - Relationships: take them from database constraints and comments, the
     source's docs, or the human. Do not guess them from column names.
   - Read the publisher's data dictionary or docs (fetch them if public). If you
     cannot read them, say so in the README and ask the human for them.
   - Look at sample rows.
   - Run no checks in this step: a join or full count can overload the database
     on a big table.
   - What you cannot learn from data or docs (how the data is created, who enters
     it, what a code means) goes to the human as a question. A guess stays labeled
     a guess until the human answers.
2. **Check each table.** Write queries on the fly. Look for anomalies, and for
   values and distributions that make no business sense.
   - **Size first:** estimate rows from the catalog (`pg_class.reltuples`). On a
     big table, explore with `TABLESAMPLE`. Scan it all only where you need an
     exact answer, like key uniqueness. Say in the record when evidence came
     from a sample.
   - **Grain:** find the key, check it is unique. If not, find what is.
   - **Low-cardinality text (attributes):** count by value, sorted by value (spots
     near-duplicates, casing, typos) and by count desc (spots rare values).
   - **Dates:** count by year, then month or day where it helps; min/max.
     Gaps, spikes, future dates, defaults like `1900-01-01`.
   - **Numbers:** min/max, count by bin. Zeros, negatives, sentinels like `9999`.
   - When something is off, dig until you can say what it is, or until only the
     human can say.
3. **Write the record** in the shape below.

## The record

`docs/profiling/<source>/_README.md`:

```markdown
# <source>

<Where the data comes from, how it is created and loaded. Mark guesses.>

| Table | Rows | Grain | Profile |
|---|---|---|---|

## Relationships
<join, cardinality, where it came from (constraint, docs, human); orphan count once checked>

## Questions for the human
1. ...
```

`docs/profiling/<source>/<table>.md`:

````markdown
# <schema>.<table>

Profiled <date>, data as of <latest load time>. <rows> rows. One row is <grain>.

## Columns
| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `item_no` | text | `100015`, `27102` | | |
| `list_on` | text → date | | 1963-06-01 – 2027-01-01 | 110 future dates (#7) |
<every column. Type: as loaded, `→ <type>` if staging should cast. Sample values
for text, Range for numbers and dates. Note only when there is something to know.>

## Issues
| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `age` | Mixes years and months | ask | open |

### 1. `age` mixes years and months
<Evidence: one sentence, plus only the rows that prove it.>

<details><summary>Query</summary>

```sql
...
```
</details>
````

- **Action:** `clean in staging: <how>`, `ask`, or `accept`.
- **Status:** `open` until the human agrees the action, then `decided`.
- **Evidence:** show the part of a distribution that proves the point. Show all
  of it only when it is short and every row matters.
- Every issue has its query, runnable as-is against the raw table.
- A check that found nothing is one line, not a section ("casts: clean for all
  numeric and date columns").
- **Full checks, on request:** the human may ask to review every distribution,
  not only the issues. Then write `<table>__checks.md`: each check run, with
  its result and query. The human reads it to judge whether each distribution
  makes business sense, and new issues go into the issues log.

## Common mistakes

| Mistake | Fix |
|---|---|
| One section per column, with every stat | Columns table plus issues. Stats appear only as evidence. |
| Recommendations in a separate list | Put each one in its issue's Action. |
| "Likely discontinued" written as fact | Write "guess" and ask the human. |
| Only min/max for a date | Count by year too. Min/max hide gaps and spikes. |
| Join count to find relationships | Ask the human, read docs or constraints. |
| Queries collected at the end, or lost | One per issue, folded under it. |
