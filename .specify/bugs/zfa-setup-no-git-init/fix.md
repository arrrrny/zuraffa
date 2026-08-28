# Fix — zfa-setup-no-git-init

- **Slug**: zfa-setup-no-git-init
- **Status**: fixed
- **Date**: 2026-08-28
- **Source issue**: https://github.com/arrrrny/zuraffa/issues/528
- **PR**: (opened below — see zfa-setup-bootstrap-gaps for the shared PR)

## Root cause

`SetupCommand._createApp` shells out to `flutter create` / `dart create` but
never runs `git init`. Modern `flutter create` no longer guarantees a `.git`,
so the documented `cd <app> && git add .` next step failed with
`fatal: not a git repository (or any of the parent directories): .git`.

## Fix

Added `SetupCommand.initializeGit(...)` and call it immediately after the app
is created (step 1.5 of `run()`). It is:

- **skipped with `--no-git`** — for CI/automation that manages its own VCS;
- **idempotent** — no-op if `.git` already exists (e.g. `flutter create`
  initialized one, or running inside an existing repo);
- **dry-run safe** — under `--dry-run` it only prints `Would run: git init`;
- **non-fatal on failure** — runs `git init` + an initial commit on success;
  a failed `git commit` (e.g. no `user.email` configured) is reported but does
  not abort the bootstrap.

## Verification

- `test/commands/setup_command_test.dart` (group `SetupCommand git init`):
  creates `.git` in a temp dir; skips with `--no-git`; idempotent when `.git`
  exists; dry-run prints intent without touching the filesystem.
- Dry-run `zfa setup demo_app --dry-run --flutter` prints `Would run: git init`.
- All setup + wirer tests pass.
