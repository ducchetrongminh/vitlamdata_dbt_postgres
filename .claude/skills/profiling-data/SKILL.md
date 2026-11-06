---
name: profiling-data
description: Use when profiling a new source or raw table before modeling it, or checking its grain, types and data quality.
---

# Profiling data

Leave a record a human reviews in one read: conclusions and issues with evidence
and query, not a log of checks.

## 1. Understand the source

- Read the loader: load mode, types as loaded. List tables, columns, sample rows.
- Read the publisher's docs. Missing, empty or unreadable: ask the human.
- Take relationships from constraints, docs or the human. Never guess.
- Run no checks here: a join or full count can overload the database.
- Ask the human what docs cannot tell (how data is created, what a code means).
  Label guesses "guess".

## 2. Check each table

Look for values and distributions without business sense.

- **Size first:** estimate rows from metadata. Big table: sample with a fixed seed,
  state the %. Full scan only for exact answers (key uniqueness).
- **Cast first:** min/max on text sorts as text (`9` after `10`).
- **Grain:** find the key and check it is unique. If not, find what is.
- **Attributes:** count by value, sorted by value (near-duplicates) and by count
  desc (rare values). Placeholders like `N/A`, `000000000000`.
- **Dates:** min/max, count by year (month, day if useful). Gaps, spikes, future
  dates, defaults like `1900-01-01`.
- **Numbers:** min/max, count by bin. Zeros, negatives, sentinels like `9999`.
- **Relationships:** test known ones with a join: orphans, key shape.
- Something off: dig until you can name it, or only the human can.

## 3. Write the record

`docs/profiling/<source>/_README.md`:

```markdown
# <source>
<Origin, how it is created and loaded.>

| Table | Rows | Grain | Profile |
|---|---|---|---|

## Relationships
<join, key shape, source, orphans, query>

## Questions for the human
```

`docs/profiling/<source>/<table>.md`:

````markdown
# <schema>.<table>
Profiled <date>, data as of <latest load time>. <rows> rows. One row is <grain>.

## Columns
| Column | Type | Sample values | Range | Note |
|---|---|---|---|---|
| `list_on` | text → date | | 1963-06-01 – 2027-01-01 | 110 future dates (#3) |

## Issues
| # | Column | Issue | Action | Status |
|---|---|---|---|---|
| 1 | `age` | Mixes years and months | ask | open |

### 1. `age` mixes years and months
<One sentence, plus only the rows that prove it.>

<details><summary>Query</summary>

```sql
...
```
</details>
````

- **Columns:** every one. `→ <type>` if staging should cast. Samples for text,
  range for numbers and dates.
- **Action:** `clean in staging: <how>`, `ask` or `accept`.
- **Status:** `open`, then `decided` once the human agrees.
- **Evidence:** only the part of a distribution that proves the point. All of it
  when short and every row matters.
- **Query:** one per issue, runnable as-is.
- **One line each:** a check that found nothing; a suspect value that is real.
- **Partial:** say so under the title, list what is left.
- **Full checks, on request:** `<table>__checks.md`, every check with result and
  query, for the human to judge distributions.
