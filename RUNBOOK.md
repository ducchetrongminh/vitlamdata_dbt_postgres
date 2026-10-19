# Runbook

How to operate this repo by hand. Design: [docs/architecture.md](docs/architecture.md).

## Local dev

dbt runs as your personal login and builds into your own schemas,
`dbt_<login>_*` (for example `dbt_duc_staging`, `dbt_duc_mart_sales`). It can read
prod but not write it.

1. **Env vars.** Copy `.env.example` to `.env` once (git-ignored). Set `PGUSER`
   to your login and `PGPASSWORD` to your dev password (see "Set a personal dev
   password" below). `profiles.yml` reads both. Load them in each shell:

   ```bash
   source .venv/bin/activate
   set -a; . ./.env; set +a
   ```

2. **Tunnel.** Open it in its own terminal and keep it running (see "Open the
   tunnel" below). dbt connects to `localhost:5433`.

3. **Check the connection.**

   ```bash
   dbt debug --profiles-dir . --target dev
   ```

   It ends with `All checks passed!`.

4. **Build.**

   ```bash
   dbt build --profiles-dir .
   ```

   `dev` is the default target. To see where a model lands on prod without
   running it: `dbt compile --profiles-dir . --target prod -s <model>`.

5. **Lint.**

   ```bash
   sqlfluff lint models/
   ```

A mart with a column named like `email`, `phone`, `name` or `address` and no
`_hash` suffix fails its own build (`macros/assert_no_pii_columns.sql`). Hash PII
in staging with `{{ hash_pii('column') }}`.

## Warehouse Terraform (`terraform/`)

Manages the `vitlamdata_dw` database on `postgres-dw`: roles, schemas, grants
(architecture §4, §7, §9). Tables belong to dbt and dlt.

Apply runs only in CI. Locally you validate the code and use `psql` through the
tunnel as your personal login. The superuser is used only on the VM, and only
when a task needs it.

You need Terraform >= 1.11 and, for `psql`, `gcloud` and an OS Login on the VM.

### Validate locally

```bash
cd terraform
terraform init -backend=false
terraform validate
terraform fmt -check
```

`-backend=false` skips the state bucket, so this needs no credentials.

### Plan and apply (CI only)

`.github/workflows/terraform.yml` plans on every PR that touches `terraform/` and
posts the plan as a comment. On merge to `main` it applies, then runs
`pii_key.sql` and `check_privileges.sql` as `postgres`. Every job runs in the
GitHub Environment `admin`, the only one the `dbt-terraform` service account
accepts. Fork PRs get no plan job.

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

### Read a plan comment

Each push to the PR adds a comment titled with its short commit SHA. Read the
newest one. Check the summary line `Plan: X to add, Y to change, Z to destroy`:

- **destroy** above 0 needs a reason. A resource with `prevent_destroy` fails
  the plan instead of showing up here.
- **`must be replaced`** on a role, schema or database means a `DROP` and a
  `CREATE`. Their contents and grants go with it. Do not merge that by accident.
- Role passwords show as `(write-only attribute)`. They never appear in a plan.
- `No changes.` is the normal result for a PR that does not touch the warehouse.

Merging applies what you read, against `main` as it is at that moment.

### Re-run a failed apply

Find the cause in the job log first. A failure in `Write private.pii_key` or
`Check privileges` happens after Terraform has already applied.

Then run it again on `main`: **Actions → terraform → Run workflow**. It applies
`main` as it is now. Use this rather than **Re-run jobs** on an old run. A re-run
checks out that run's commit, so it can undo a newer merge.

Every step is safe to repeat. Apply is a no-op once the warehouse matches the
code. `pii_key.sql` leaves the existing key row as it is.

A held state lock (`Error acquiring the state lock`) means another run is still
going, or one was killed. Wait for the other run. If none is running, delete the
lock object `gs://vitlamdata_dbt_postgres/warehouse/default.tflock`.

### Rebuilt warehouse

The warehouse has no backup (architecture §1). After the `postgres-dw` data is
lost, run the apply again (Run workflow). It recreates the database, roles,
schemas and grants. Then `pii_key.sql` inserts the same key from `dw-pii-key`,
so every hash comes out as before. Then rebuild the data: nightly with
`full_refresh`. Personal dev passwords are gone: set them again (below).

### Superuser on the VM

Only for tasks a personal login cannot do: setting a dev password, running the
privilege check by hand. It needs `sudo` on the VM (admin OS Login). It goes
through the container's local socket, so no password and no tunnel:

```bash
gcloud compute ssh vitlamdata-vm-2609 --zone asia-southeast1-c -- -t \
  sudo docker exec -it postgres-dw psql -U postgres -d vitlamdata_dw
```

### Set a personal dev password

Personal logins (`postgresql_role.dev` in `terraform/roles.tf`) have no secret.
After the apply that creates yours, open the superuser psql above and run:

```
\password duc
```

Keep it in your password manager. Terraform does not touch it.

### Open the tunnel

Keep this running in its own terminal:

```bash
gcloud compute ssh vitlamdata-vm-2609 --zone asia-southeast1-c -- -N -L 5433:127.0.0.1:5433
```

### Connect with psql

Copy `.env.example` to `.env` (git-ignored) once and set `PGUSER` to your login.
In each shell:

```bash
set -a; . ./.env; set +a
psql
```

`psql` asks for your dev password. As a member of `developer` you can read the
prod schemas and create your own, but not write prod.

### Check privileges

CI runs this after every apply. It switches to each role with `SET ROLE`, so by
hand it runs as the superuser on the VM:

```bash
gcloud compute ssh vitlamdata-vm-2609 --zone asia-southeast1-c -- \
  sudo docker exec -i postgres-dw psql -U postgres -d vitlamdata_dw < terraform/check_privileges.sql
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
