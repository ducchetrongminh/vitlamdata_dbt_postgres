# Bus matrix

Business processes (rows) against conformed dimensions (columns). `X`: the fact
table has that dimension. A design file holds the process's four-step design and
bubble chart; processes built before the design skill have none.

| Business process | Fact table | Design | WP User | WP Course | WP Coupon | Date | Store | Product | Vendor | Category |
|---|---|---|---|---|---|---|---|---|---|---|
| Course order | `fact_order_line` | — | X (ordered by) | X | X | X¹ | | | | |
| Course enrollment | `fact_enrollment` | — | X (student) | X | | X¹ | | | | |
| Lead sign-up | `fact_lead` | — | | | | X¹ | | | | |
| Liquor order | — | [liquor_order.md](liquor_order.md) | | | | X (ordered on) | X | X | X | X |

¹ A date or timestamp column on the fact (`ordered_at`, `enrolled_at`,
`submitted_at`), not yet a date dimension. Liquor order is the first fact
designed with the Date dimension.

`dim_wp_instructor` is on no fact table: courses reference it (`dim_wp_course.wp_instructor_key`).
