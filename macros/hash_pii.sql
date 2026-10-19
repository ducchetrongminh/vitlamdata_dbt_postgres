{#-
    Keyed hash for PII columns, used in staging (docs/architecture.md §6).
    The key is read by subquery from private.pii_key, never through env_var(),
    so it never lands in target/, manifest.json, the docs or the query logs.
    hmac() is pgcrypto's, in schema public.
-#}
{% macro hash_pii(col) -%}
    encode(hmac(lower(trim({{ col }})), (select key from private.pii_key), 'sha256'), 'hex')
{%- endmacro %}
