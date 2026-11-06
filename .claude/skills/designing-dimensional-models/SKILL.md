---
name: designing-dimensional-models
description: Use when designing a new fact table or mart, or changing the grain or dimensions of an existing one, before writing mart models.
---

# Designing dimensional models

Kimball's four-step design, done with the human one step at a time. Output: a
bubble chart per fact table and a row in the bus matrix. High-level only: columns,
naming, history handling and materialization come later, in detailed design.

## Before step 1

- Read the profiling record of each source table (`docs/profiling/<source>/`).
  Missing or partial: ask the human, then profile with profiling-data. Data issues
  go there, not here.
- Read `docs/design/_bus_matrix.md`. Reuse its conformed dimensions.

## The four steps

For each step: propose one decision, its reason and evidence. Stop and wait for the
human. Write the step into the file once approved, then start the next.

1. **Business process:** the operational activity that creates the events (stores
   order liquor from the state), not a department or a report. Reason: what the
   rows record and why that is the process.
2. **Grain:** what one fact row is, in business terms. Pick the finest grain the
   data supports. Cite the profiling record: key, uniqueness, issues that bear on it.
3. **Dimensions:** who, what, where, when, why, how. Each has one value per fact row.
   One with several values per row: drop it, change the grain, or use a multivalued
   design. The human picks.
4. **Facts:** numeric measurements true to the grain. Mark each additive,
   semi-additive or non-additive. A fact at another grain belongs in another fact table.

A later step can reopen an earlier one (a dimension that does not fit the grain).
Say so and go back; do not patch around it.

## After step 4

Draw the bubble chart, update the bus matrix, and have the human approve both.

`docs/design/<business_process>.md`:

````markdown
# <Business process>

Sources: [<table>](../profiling/<source>/<table>.md)

## 1. Business process
<decision>. Why: <reason>.

## 2. Grain
One row per <...>. Why: <reason, evidence>.

## 3. Dimensions
| Dimension | One value per row because | Conformed with |
|---|---|---|

## 4. Facts
| Fact | Additivity | Note |
|---|---|---|

## Bubble chart
```mermaid
flowchart LR
    date[Date] --- f["<b>Sales</b><br/>Grain: 1 row per invoice line"]
    f --- store[Store]
```

## Open questions
````

- **Bubble chart:** for non-technical readers. Business names, the grain in the fact
  bubble, no columns or keys. Same dimension order across a process's charts.
- **One file per process:** several fact tables at different grains each get a chart.
- **Bus matrix:** one row per business process and fact table, one column per
  conformed dimension, `X` where used. Link the row to its design file.
