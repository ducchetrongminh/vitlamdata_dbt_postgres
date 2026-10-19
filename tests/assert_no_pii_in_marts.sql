-- Fails for any mart column whose name looks like PII and is not a hash
-- (docs/architecture.md §6). Checks the mart schemas of the current target:
-- mart_* on prod, dbt_<user>_mart_* on dev, ci_pr_<n>_mart_* on CI.
-- It has no parents, so dbt build may run it before the marts: the post-hook
-- assert_no_pii_columns() is what stops each mart as it is built.
{%- set mart_prefix = generate_schema_name('mart_', none) | trim %}

select
    table_schema,
    table_name,
    column_name
from information_schema.columns
where
    -- _ is a LIKE wildcard: escape it so dbt_duc_mart_ matches only itself
    table_schema like replace('{{ mart_prefix }}', '_', '\_') || '%'
    and {{ is_pii_column('column_name') }}
