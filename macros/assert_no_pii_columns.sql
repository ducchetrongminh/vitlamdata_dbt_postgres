{#- Column names that look like PII and are not hashes (docs/architecture.md §6). -#}
{% macro is_pii_column(col) -%}
    ({{ col }} ~* '(email|phone|name|address)' and {{ col }} !~* '_hash$')
{%- endmacro %}

{#-
    Post-hook on every 03_mart model: fails its build if the table just built has
    a PII-looking column. It runs inside the model's transaction, so the bad table
    is rolled back. Unlike tests/assert_no_pii_in_marts.sql, it cannot run before
    the model or be left out of a slim CI selection.
-#}
{% macro assert_no_pii_columns() -%}
do $$
declare
    bad text;
begin
    select string_agg(column_name, ', ') into bad
    from information_schema.columns
    where
        table_schema = '{{ this.schema }}'
        and table_name = '{{ this.identifier }}'
        and {{ is_pii_column('column_name') }};
    if bad is not null then
        raise exception 'PII column(s) in {{ this }}: %. Hash them in staging with hash_pii().', bad;
    end if;
end $$
{%- endmacro %}
