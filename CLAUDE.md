# CLAUDE.md

## Git workflow: branch, commit, PR

Every change Claude makes is tracked in git so the reviewer can see what Claude did, then their own review and revisions, one step at a time.

1. Never commit to `main`. Before editing, check out a new branch from `main` (`feat/…`, `fix/…`, `docs/…`).
2. If the working tree already has uncommitted changes from the user, commit them first as-is, as the baseline. Then start Claude's own changes.
3. Commit each logical change on its own, with a Conventional Commits message. Push after each commit.
4. Open a PR against `main` after the first push. Later commits go to the same PR.
5. When a commit comes from the reviewer's feedback, quote the feedback verbatim in the commit body under `Reviewer feedback:`, then add a `Why:` line stating the reason for the change. This repo doubles as learning material, so every change must show what prompted it.

   ```
   refactor: rename order line item_wp_post_id to wp_course_id

   Reviewer feedback:
   > let's rename item_wp_post_id to wp_course_id (we will combine course and
   > bundle into 1 model)

   Why: courses and course bundles will be one entity, wp_course.
   ```
6. The reviewer's revisions land as new commits on the same branch. Never amend, squash, rebase or force-push commits already pushed — the commit history is the review record.
7. Finish the current branch's PR before starting unrelated work on a new branch.

## Environment

Run Python and dbt from the project venv: `source .venv/bin/activate && dbt …`. Not `uv run`.

## Conventions

Read before changing any model:

- [docs/dbt-layers-conventions.md](docs/dbt-layers-conventions.md)
- [docs/dw-naming-conventions.md](docs/dw-naming-conventions.md)
- [docs/dimensional-modeling-standards.md](docs/dimensional-modeling-standards.md)
- [docs/architecture.md](docs/architecture.md)

## External datasets

This repo centres on VitLamData data. An external dataset with no link to it
(e.g. `iowa_data_hub`, a public data portal used for practice) is its own bus: design files and
bus matrix go in `docs/design-external/<source>/`, not `docs/design/`, and its
conformed dimensions do not mix with VitLamData's. So its dimensions can take
simple names (Store, Vendor). dbt model names are unique across the whole
project, so prefix every intermediate and mart model of an external dataset
with its source, and set `alias` to the simple table name: model
`iowa_data_hub__dim_store`, table `dim_store`. Its models go in `models_external/`, with the same layer folders
(`models_external/03_mart/iowa_data_hub/`); `dbt_project.yml` layer configs
cover both folders. Its marts land in schema `mart_ext_<source>`
(`mart_ext_iowa_data_hub`). Its seeds stay in `seeds/<source>/`. Staging models already carry the
source (`stg_iowa_data_hub__…`).
