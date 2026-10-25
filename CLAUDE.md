# CLAUDE.md

## Git workflow: branch, commit, PR

Every change Claude makes is tracked in git so the reviewer can see what Claude did, then their own review and revisions, one step at a time.

1. Never commit to `main`. Before editing, check out a new branch from `main` (`feat/…`, `fix/…`, `docs/…`).
2. If the working tree already has uncommitted changes from the user, commit them first as-is, as the baseline. Then start Claude's own changes.
3. Commit each logical change on its own, with a Conventional Commits message. Push after each commit.
4. Open a PR against `main` after the first push. Later commits go to the same PR.
5. The reviewer's revisions land as new commits on the same branch. Never amend, squash, rebase or force-push commits already pushed — the commit history is the review record.
6. Finish the current branch's PR before starting unrelated work on a new branch.

## Environment

Run Python and dbt from the project venv: `source .venv/bin/activate && dbt …`. Not `uv run`.

## Conventions

Read before changing any model:

- [docs/dbt-layers-conventions.md](docs/dbt-layers-conventions.md)
- [docs/dw-naming-conventions.md](docs/dw-naming-conventions.md)
- [docs/dimensional-modeling-standards.md](docs/dimensional-modeling-standards.md)
- [docs/architecture.md](docs/architecture.md)
