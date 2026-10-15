-- private.pii_key: the one-row HMAC key for macros/hash_pii.sql
-- (docs/architecture.md §6). Terraform cannot create tables, so this runs after
-- apply, as postgres. Safe to rerun: it never changes an existing key, so a
-- rebuilt warehouse gets the same key back and every hash stays the same.
-- Grants come from the default privileges on `private` (grants.tf).
--
-- psql -v key="$(gcloud secrets versions access latest --secret=dw-pii-key)" -f terraform/pii_key.sql
\set ON_ERROR_STOP on

create table if not exists private.pii_key (
    one boolean primary key default true check (one), -- at most one row
    key text not null check (key <> '')
);

insert into private.pii_key (key) values (:'key')
on conflict do nothing;
