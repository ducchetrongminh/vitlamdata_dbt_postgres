# Bus matrix: Iowa Data Hub

Business processes (rows) against conformed dimensions (columns). `X`: the fact
table has that dimension. This bus is separate from VitLamData's
(`docs/design/_bus_matrix.md`): its dimensions conform only within the Iowa Data Hub.

| Business process | Fact table | Design | Date | Store | Product | Vendor | Category |
|---|---|---|---|---|---|---|---|
| Liquor order | — | [liquor_order.md](liquor_order.md) | X (ordered on) | X | X | X | X |

The fact table is named in detailed design.
