{#-
    Prod uses the custom schema as written (staging, mart_sales). Dev and CI keep
    dbt's default <target_schema>_<custom> (dbt_duc_mart_sales, ci_pr_12_mart_sales),
    so they never write prod schemas. docs/architecture.md §5.
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if target.name == 'prod' and custom_schema_name is not none -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default__generate_schema_name(custom_schema_name, node) }}
    {%- endif -%}
{%- endmacro %}
