# Runbook

How to operate this repo by hand. Design: [docs/architecture.md](docs/architecture.md).

## Warehouse Terraform (`terraform/`)

Manages the `vitlamdata_dw` database on `postgres-dw`: roles, schemas, grants
(architecture §4, §7, §9). Tables belong to dbt and dlt.

Apply runs only in CI. Locally you validate the code and use `psql` through the
tunnel.

You need Terraform >= 1.11 and, for `psql`, `gcloud`, an OS Login on the VM and
read access to the `dw-superuser` secret.

### Validate locally

```bash
cd terraform
terraform init -backend=false
terraform validate
terraform fmt -check
```

`-backend=false` skips the state bucket, so this needs no credentials.

### Plan and apply (CI only)

`terraform.yml` (#4) plans on every PR and posts the plan as a comment. On merge
to `main` it applies, then runs `pii_key.sql` and `check_privileges.sql`.

Never run `terraform plan` or `terraform apply` locally. A local apply skips
review and races CI on the same state.

CI runs both with `-parallelism=1`. Grants on one schema update the same catalog
row, and in parallel they fail with `pq: tuple concurrently updated`.

Role passwords come from the secrets `dw-loader`, `dw-transformer`, `dw-ci` and
`dw-reporter-public`. To rotate one: add a new secret version, bump
`password_version` in `terraform/roles.tf`, open a PR and merge it.

The PII key comes from `dw-pii-key`. `pii_key.sql` never overwrites an existing
key. Changing the key changes every hash and needs a full refresh of all
incremental models (architecture §6).

### Open the tunnel

Keep this running in its own terminal:

```bash
gcloud compute ssh vitlamdata-vm-2609 --zone asia-southeast1-c -- -N -L 5433:127.0.0.1:5433
```

### Connect with psql

Copy `.env.example` to `.env` (git-ignored) once. It holds the connection
settings, not the password. In each shell:

```bash
set -a; . ./.env; set +a
export PGPASSWORD="$(gcloud secrets versions access latest --secret=dw-superuser)"
psql
```

### Set a personal dev password

Personal logins (`postgresql_role.dev` in `terraform/roles.tf`) have no secret.
After the apply that creates yours, set its password as `postgres`:

```bash
psql -c '\password duc'
```

Keep it in your password manager. Terraform does not touch it.

### Check privileges

CI runs this after every apply. To run it by hand, connect as in "Connect with
psql", then:

```bash
psql -f terraform/check_privileges.sql
```

It ends with `all privilege checks passed` and leaves nothing behind.

### Remove a protected resource

Every database, role and schema has `lifecycle { prevent_destroy = true }`.
Apply runs on merge, so this guard is the only thing stopping an accidental `DROP`.
Removing one takes two PRs on purpose:

1. Delete the `prevent_destroy` line from that resource (or `for_each` block). Merge.
2. Delete the resource (or its map entry). Merge. The apply drops it.

A role must own nothing before Postgres lets it be dropped. Reassign or drop its
objects first.
