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
   sqlfluff lint models/ models_external/
   ```

A mart fails its own build (`macros/assert_no_pii_columns.sql`) when a column:

- has a name containing `email`, `phone`, `address`, `first_name`, `last_name`,
  `full_name`, `user_name`, `display_name` or `learner_name`, with no `_hash`
  suffix. `course_name` and the like pass;
- or is marked PII in the model's yml, whatever its name:
  `meta: {pii: true}` (or under `config:`).

Hash PII in staging with `{{ hash_pii('column') }}`.

## Ingestion (`ingestion/`)

dlt copies each source into `raw_<source>` (architecture §3). Nightly runs it
as `loader`. Each source is a folder, `ingestion/<source>/`: `pipeline.py` runs it, and
`.dlt/config.toml` holds its tables, write dispositions and cursors.
Credentials for all sources are in `ingestion/credentials.toml` as `${VAR}`
references to env vars, like `env_var()` in `profiles.yml`; `ingestion/setup.py`
fills them in. Sources: `wordpress`, `iowa_data_hub`.

Its dependencies are the `ingestion` group in `pyproject.toml`, in the same `.venv`.

### Run one source load locally

Your login cannot write `raw_*`, so load into a schema of your own. It needs
the tunnel to forward 3306 too:

```bash
gcloud compute ssh vitlamdata-vm-2609 --zone asia-southeast1-c -- -N \
  -L 3306:127.0.0.1:3306 -L 5433:127.0.0.1:5433
```

In `.env`, set the `MARIADB_*` vars (`.env.example`). The warehouse login
reuses your `PG*` values. Then, from the repo root:

```bash
source .venv/bin/activate
set -a; . ./.env; set +a
WORDPRESS__DATASET_NAME=dbt_duc_raw_wordpress python -m ingestion.wordpress.pipeline
```

dlt creates that schema and its `_staging` twin. To reload every table and
reset the cursors (what nightly `full_refresh` does), add `REFRESH=drop_data`.
When done, drop both schemas and the local pipeline state,
`~/.dlt/pipelines/wordpress`; otherwise its saved cursor makes the
next load into a fresh schema skip rows.

### Nightly and manual loads

`nightly.yml` runs at 02:00 ICT: `ingest.yml` loads every source, then
`dbt-build.yml` builds prod, then `notify` posts the result to Lark. All run in
GitHub Environment `prod`, as `dbt-runner`.

Each run's summary page lists, per source, the rows loaded into each table. A
`merge` table shows only new or changed rows, often 0. The job log has dlt's
step logs (`log_level = "INFO"` in each `.dlt/config.toml`).

- **Load now, without dbt:** Actions → ingest → Run workflow.
- **Re-run a failed nightly:** Actions → nightly → Run workflow. A load is safe
  to repeat: merge tables update in place, replace tables are reloaded.
- **Build now, without loading:** Actions → dbt-build → Run workflow.
- **Deploy on merge:** a merge to `main` that touches `models/`, `models_external/`, `macros/`,
  `tests/`, `seeds/`, `snapshots/` or the dbt config files runs `deploy.yml`. It
  builds in prod only the changed models and their children, then uploads the
  manifest and the docs. It waits while nightly holds prod. If it fails, fix in a
  new PR: its merge deploys again. Or run dbt-build for a full build.
- **full_refresh:** tick it after rows were hard-deleted in a source, or after
  a model logic change. It reloads every table from scratch and rebuilds
  every model with `--full-refresh`. Use it on nightly, not on ingest alone:
  reloading raw without the dbt rebuild leaves incremental marts stale.
- **Pause the schedule:** `gh workflow disable nightly.yml`, e.g. while the VM
  disk is nearly full. Turn it back on with `gh workflow enable nightly.yml`.
  A disabled workflow cannot be run by hand either: use ingest and dbt-build.

### Read a Lark alert

`nightly passed` or `nightly FAILED`, then the result of each job and the run link:

- `ingest: failure`, `build: skipped`: a source did not load. Open the run, then the
  `ingest` job's "Load sources" step; each source is its own log group. dbt did
  not run, so prod still holds yesterday's data.
- `ingest: success`, `build: failure`: open the `build` job. "Source freshness"
  fails when a source has not loaded for 50 h; "dbt build" lists the failed models
  and tests. The manifest and docs were not updated.
- No alert at all: the `notify` job failed (Lark rejected the message; its log
  says why) or `LARK_WEBHOOK_URL` is not set (the job logs a warning).

The bot is the custom bot in the infras report group in Lark. Not the one in
`vitlamdata-env`: that URL posts to the CS group. To set or rotate it:

1. In the Lark group: Settings → Bots → the custom bot → copy the webhook URL.
   If "Signature verification" is on, copy its secret too.
2. Set them in environment `prod`. Each command prompts for the value, so it
   never lands in shell history:

   ```bash
   gh secret set LARK_WEBHOOK_URL --env prod -R ducchetrongminh/vitlamdata_dbt_postgres
   # only if signature verification is on:
   gh secret set LARK_SIGNING_SECRET --env prod -R ducchetrongminh/vitlamdata_dbt_postgres
   ```

3. Run nightly (or wait for it) and check the alert lands in the group.

Fix, then re-run (above). Rotating the PII key changes every hash: run nightly
with `full_refresh` after it (see "Warehouse Terraform").

### dbt docs

`dbt-build.yml` publishes `dbt docs generate --static` to GitHub Pages after each
successful build. It holds SQL and column names, no data and no key (architecture §10).

One-time setup: Settings → Pages → Source: GitHub Actions. Without it the `docs`
job fails, and nightly alerts `build: failure` although models and manifest are fine.

### Add a table

1. Add it to `table_names` under `[sources.wordpress]` in
   `ingestion/wordpress/.dlt/config.toml`. It gets the default, `replace`.
2. If it holds credentials (password hashes, tokens, keys), keep them out:
   columns with `excluded_columns` in the table's own section, like `wp_users`;
   rows with a query filter in `pipeline.py`, like `wp_usermeta`.
3. Run a local load and check the table.

### Switch a table from replace to merge

Only when the table has a cursor column that changes on every update
(architecture §3), and a primary key in the source (dlt reads it from there).

1. Give the table its own section in `ingestion/wordpress/.dlt/config.toml`, like `wp_posts`:

   ```toml
   [sources.wordpress.wp_posts]
   write_disposition = { disposition = "merge" }
   incremental = { cursor_path = "post_modified_gmt" }
   ```

2. Run a local load twice, then check that the primary key has no duplicates:

   ```sql
   select count(*), count(distinct id) from dbt_duc_raw_wordpress.wp_posts;
   ```

Merge does not see hard deletes. Nightly with `full_refresh` truncates every
table and reloads it, which catches them.

## PR checks (`ci.yml`, `ci-cleanup.yml`)

Every PR runs two jobs:

- `lint`: `sqlfluff lint` on the `.sql` files the PR adds or changes, not
  `macros/`. Older models still fail lint, so touching one means fixing its
  violations too. Same check locally: `sqlfluff lint <file>`.
- `build`: same-repo PRs only (a fork PR runs `lint` alone). It builds the
  changed models and their children into `ci_pr_<n>_*` as login `ci`, and reads
  everything else from prod (`--defer`). A new push cancels the build still
  running for the same PR.

### Find a PR's schemas

PR 12's models land in `ci_pr_12_<custom>`, e.g. `ci_pr_12_staging`,
`ci_pr_12_mart_sales`. They stay after the run, for review:

```sql
select nspname from pg_namespace where nspname ~ '^ci_pr_12(_|$)';
```

### Drop leftovers by hand

`ci-cleanup.yml` drops `ci_pr_<n>` and `ci_pr_<n>_*` when the PR closes, merged
or not. Fork PRs and a failed cleanup leave them behind. List every CI schema
with `select nspname from pg_namespace where nspname ~ '^ci_pr_'`, then drop
one PR's as `ci` (the owner), or as superuser:

```sql
select format('drop schema %I cascade', nspname)
from pg_namespace where nspname ~ '^ci_pr_12(_|$)'
\gexec
```

Use the regex, not `like 'ci_pr_1_%'`: in `like`, `_` matches any character,
so that also drops PR 12's schemas.

### Missing or stale prod manifest

`build` compares the PR with `gs://vitlamdata_dbt_postgres/dbt-state/manifest.json`,
uploaded by each successful prod build (`dbt-build.yml`).

- **Missing** (before the first prod build): the job warns
  `No prod manifest yet: full build` and builds every model into `ci_pr_<n>_*`.
- **Stale** (last prod build failed, or a merged PR not yet built): models
  that differ from that manifest count as modified, so the PR also rebuilds
  them. `--defer` reads unchanged parents from prod as they are now. To refresh
  it, run Actions → dbt-build, then re-run the PR's `ci` workflow.

## Claude Code Remote Control

Recommended. `.devcontainer/postCreate.sh` turns it on for all your sessions in
`~/.claude/settings.json` unless you already set it. To opt out, set `false`:

```json
{ "remoteControlAtStartup": false }
```

## Warehouse Terraform (`terraform/warehouse/`)

Manages the `vitlamdata_dw` database on `postgres-dw`: roles, schemas, grants
(architecture §4, §7, §9). Tables belong to dbt and dlt.

Apply runs only in CI. Locally you validate the code and use `psql` through the
tunnel as your personal login. The superuser is used only on the VM, and only
when a task needs it.

You need Terraform >= 1.11 and, for `psql`, `gcloud` and an OS Login on the VM.

### Validate locally

```bash
cd terraform/warehouse
terraform init -backend=false
terraform validate
terraform fmt -check
```

`-backend=false` skips the state bucket, so this needs no credentials.

### Plan and apply (CI only)

`.github/workflows/terraform.yml` plans on every PR that touches `terraform/warehouse/` and
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
`password_version` in `terraform/warehouse/roles.tf`, open a PR and merge it.

The PII key comes from `dw-pii-key`. `pii_key.sql` never overwrites an existing
key. Changing the key changes every hash and needs a full refresh of all
incremental models (architecture §6).

### Metabase Terraform (`terraform/metabase/`)

Manages Metabase through its API with the `flovouin/metabase` provider: the
warehouse connection, collections, groups and permissions. It has its own state
(GCS prefix `metabase`) and its own workflow, `terraform-metabase.yml`, with the
same plan-on-PR, apply-on-merge flow. Validate it the same way, from
`terraform/metabase`.

It logs in with an admin API key from the secret `metabase-api-key`. To rotate
it, create a new key in **Admin → Settings → Authentication → API keys** (group
Administrators), add it as a new secret version, then delete the old key:

```bash
printf %s "<key>" | gcloud secrets versions add metabase-api-key --data-file=-
```

Do not cancel a running Metabase Terraform job. A killed run leaves its state
lock behind, and every later run then fails with `Error acquiring the state
lock`. If that happens, check that no Metabase run is in progress, then remove
the lock:

```bash
gcloud storage rm gs://vitlamdata_dbt_postgres/metabase/default.tflock
```

The Metabase API is unversioned and changes between releases. Before upgrading
Metabase, check the provider's compatibility table and bump the provider pin in
`terraform/metabase/main.tf` if needed.

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

Personal logins (`postgresql_role.dev` in `terraform/warehouse/roles.tf`) have no secret.
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
prod schemas and each PR's `ci_pr_<n>_*` schemas, and create your own, but not
write prod or CI.

### Check privileges

CI runs this after every apply. It switches to each role with `SET ROLE`, so by
hand it runs as the superuser on the VM:

```bash
gcloud compute ssh vitlamdata-vm-2609 --zone asia-southeast1-c -- \
  sudo docker exec -i postgres-dw psql -U postgres -d vitlamdata_dw < terraform/warehouse/check_privileges.sql
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
