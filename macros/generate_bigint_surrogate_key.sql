{#- dbt_utils.generate_surrogate_key cut to its first 64 bits, as a bigint: 8 bytes, not the
    33 of the md5 text. Two keys of one table collide with odds about n² / 2^65 (1 in 10^11 at
    13k rows); a dimension's primary key constraint would catch it. -#}
{% macro generate_bigint_surrogate_key(field_list) %}
    {{- "('x' || left(" ~ dbt_utils.generate_surrogate_key(field_list) ~ ", 16))::bit(64)::bigint" -}}
{% endmacro %}
