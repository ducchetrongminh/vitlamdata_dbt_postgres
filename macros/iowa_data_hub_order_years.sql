{#- The years of the Iowa sales tables declared as sources (liquor_sales_<year>), sorted.
    Adding a year's source adds the year. Empty at parse time, when the graph is not built
    yet: so a model's source() calls show in its lineage only once compiled, and
    `-s source:iowa_data_hub.liquor_sales_<year>+` selects nothing. -#}
{% macro iowa_data_hub_order_years() %}
    {%- set years = [] %}
    {%- for source in graph.get('sources', {}).values()
        if source.source_name == 'iowa_data_hub'
        and source.name.startswith('liquor_sales_') and source.name[-4:].isdigit() %}
        {%- do years.append(source.name[-4:] | int) %}
    {%- endfor %}
    {{- return(years | sort) }}
{% endmacro %}
