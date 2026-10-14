# Runbook

How to operate this repo by hand. Design: [docs/architecture.md](docs/architecture.md).

## Warehouse Terraform (`terraform/`)

Manages the `vitlamdata_dw` database on `postgres-dw`: roles, schemas, grants
(architecture §4, §7, §9). Tables belong to dbt and dlt.

You need Terraform >= 1.11, `psql`, `gcloud`, an OS Login on the VM, and read
access to the `dw-*` secrets and the `vitlamdata_dbt_postgres` bucket.

### Open the tunnel

Keep this running in its own terminal:

```bash
gcloud compute ssh vitlamdata-vm-2609 --zone asia-southeast1-c -- -N -L 5433:127.0.0.1:5433
```

### Plan and apply

```bash
gcloud auth application-default login   # once; Terraform reads secrets and state with it
export PGPASSWORD="$(gcloud secrets versions access latest --secret=dw-superuser)"
cd terraform
terraform init
terraform plan -parallelism=1
terraform apply -parallelism=1
```

`-parallelism=1` is required. Grants on one schema update the same catalog row,
and in parallel they fail with `pq: tuple concurrently updated`.

Role passwords come from the secrets `dw-loader`, `dw-transformer`, `dw-ci` and
`dw-reporter-public`. To rotate one: add a new secret version, bump
`password_version` in `terraform/roles.tf`, apply.

### Write the PII key

Run once after the first apply, and after any rebuild of the warehouse. It never
overwrites an existing key.

```bash
export PGHOST=127.0.0.1 PGPORT=5433 PGUSER=postgres PGDATABASE=vitlamdata_dw
psql -v key="$(gcloud secrets versions access latest --secret=dw-pii-key)" -f terraform/pii_key.sql
```

Changing the key changes every hash and needs a full refresh of all incremental
models (architecture §6).

### Set a personal dev password

Personal logins (`postgresql_role.dev` in `terraform/roles.tf`) have no secret.
After the apply that creates yours, set its password as `postgres`:

```bash
psql -c '\password duc'
```

Keep it in your password manager. Terraform does not touch it.

### Check privileges

With the `PG*` variables above:

```bash
psql -f terraform/check_privileges.sql
```

It ends with `all privilege checks passed` and leaves nothing behind. Then a
second `terraform plan -parallelism=1` must show no changes.

### Remove a protected resource

Every database, role and schema has `lifecycle { prevent_destroy = true }`.
Apply runs on merge, so this guard is the only thing stopping an accidental `DROP`.
Removing one takes two PRs on purpose:

1. Delete the `prevent_destroy` line from that resource (or `for_each` block). Merge.
2. Delete the resource (or its map entry). Merge. The apply drops it.

A role must own nothing before Postgres lets it be dropped. Reassign or drop its
objects first.
