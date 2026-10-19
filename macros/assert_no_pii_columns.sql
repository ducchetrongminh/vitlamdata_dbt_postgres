{#-
    Column names that look like PII and are not hashes (docs/architecture.md §6).
    `name` only in these forms, so course_name or dashboard_name pass.
-#}
{% macro is_pii_column(col) -%}
    (
        {{ col }} ~* '(email|phone|address|first_name|last_name|full_name|user_name|display_name|learner_name)'
        and {{ col }} !~* '_hash$'
    )
{%- endmacro %}

{#-
    Post-hook on every 03_mart model: fails its build if the table just built has
    a PII-looking column, or a column marked PII in its yml whatever its name:

        columns:
          - name: contact
            meta: {pii: true}

    It runs inside the model's transaction, so the bad table is rolled back.
    Unlike tests/assert_no_pii_in_marts.sql, it cannot run before the model or be
    left out of a slim CI selection.
-#}
{% macro assert_no_pii_columns() -%}
    {%- set marked = [] -%}
    {%- for col in model.columns.values() -%}
        {#- meta sits on the column or, from dbt 1.10, under its config -#}
        {%- if (col.meta or {}).get('pii') or ((col.config or {}).get('meta') or {}).get('pii') -%}
            {%- do marked.append("'" ~ col.name ~ "'") -%}
        {%- endif -%}
    {%- endfor -%}
do $$
declare
    bad text;
begin
    select string_agg(column_name, ', ') into bad
    from information_schema.columns
    where
        table_schema = '{{ this.schema }}'
        and table_name = '{{ this.identifier }}'
        and (
            {{ is_pii_column('column_name') }}
            {%- if marked %}
            or column_name in ({{ marked | join(', ') }})
            {%- endif %}
        );
    if bad is not null then
        raise exception 'PII column(s) in {{ this }}: %. Hash them in staging with hash_pii().', bad;
    end if;
end $$
{%- endmacro %}
