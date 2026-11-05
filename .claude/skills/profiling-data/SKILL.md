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
   - List schemas, tables and columns. Guess relationships from column names, then
     confirm them with a join count.
   - Read the publisher's data dictionary or docs (fetch them if public). If you
     cannot read them, say so in the README and ask the human for them.
   - Look at sample rows.
   - What you cannot learn from data or docs (how the data is created, who enters
     it, what a code means) goes to the human as a question. A guess stays labeled
     a guess until the human answers.
2. **Check each table.** Write queries on the fly. Look for anomalies and for
   values that make no business sense.
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
<join, cardinality, orphan count>

## Questions for the human
1. ...
```

`docs/profiling/<source>/<table>.md`:

````markdown
# <schema>.<table>

Profiled <date>, load <id>. <rows> rows. One row is <grain>.

## Columns
| Column | Cast to | Note |
|---|---|---|
<every column; Note only when there is something to know>

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

## Common mistakes

| Mistake | Fix |
|---|---|
| One section per column, with every stat | Columns table plus issues. Stats appear only as evidence. |
| Recommendations in a separate list | Put each one in its issue's Action. |
| "Likely discontinued" written as fact | Write "guess" and ask the human. |
| Only min/max for a date | Count by year too. Min/max hide gaps and spikes. |
| Queries collected at the end, or lost | One per issue, folded under it. |
