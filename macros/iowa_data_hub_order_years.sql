{#- The years of the Iowa sales tables liquor_sales_<year>. Each must be declared as a source in
    models_external/01_staging/iowa_data_hub/_iowa_data_hub__sources.yml: add a year in both. -#}
{% macro iowa_data_hub_order_years() %}
    {{- return(range(2012, 2027) | list) }}
{% endmacro %}
