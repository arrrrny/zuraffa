# TDD Verification — 1181-git-branch-numbering (#1181)

- **Bug**: https://github.com/arrrrny/zuraffa/issues/1181
- **Branch**: fix/1181-git-branch-numbering
- **Date**: 2026-09-06
- **Verdict**: PASS — the branch-numbering bug is reproduced red and fixed green with real CLI evidence; branch and spec directory now agree on the same counter; the Dart fast suite and analyzer are green on the fix HEAD; formatting is clean.
- **Provenance note**: `.specify/bugs/1181-git-branch-numbering/issue.md` and `assessment.md` were NOT present in the repo (the task brief said "if exists"; they do not). The task brief plus GitHub issue #1181 (fetched live) were the sole issue input; this audit adds no synthetic triage records. `zfa tdd verify` was not dispatchable (no global `zfa` binary and no `.zfa.json` in the repo root → `ZFA_MISSING`), so per the speckit.tdd.verify fallback path this audit was produced by the LLM-guided process with real red/green evidence below.

## What was actually wrong (root cause, proved from the RED run)

Auto-allocation in `create-new-feature-branch.sh` called
`check_existing_branches()` = `1 + max(highest `specs/` dir, highest number
harvested from the final segment of **every** local and remote branch matching
`^[0-9]{3,}-`)`. This repo names non-feature branches after GitHub issues
(`fix/1108-di-verify-json-envelope`, `spec/1106-verify-json-gaps`, …). Those
segments pass the filter, so the "sequential feature counter" ingested the
GitHub-issue stream: max issue-numbered branch 1108 + 1 = **1109** —
structurally equal to the next issue number the feature description
references (`#1109`), which is why the observed branch looked like it was
"derived from the description". The spec-directory resolution
(`create-new-feature.sh`) counts only `specs/`, so the branch (1109) could
never match the eventual spec directory (077), violating the AGENTS.md rule
"branch name MUST match the feature directory name exactly".

## Environment (honest constraints)

- Toolchain: Dart SDK 3.13.3 stable, linux-x64 (task requires Dart 3.13+). Flutter not installed; the fast suite excludes flutter-tagged tests by design (`tools/run_tests_chunked.sh` drops them).
- Disk: ~8 GB free; the chunked runner was used exactly as the repo prescribes for small cloud agents (kernel-cache cleanup between chunks).
- The bug fix itself is bash + docs; the Dart suite is the repo's regression gate and was run in full anyway.
- Spec-kit: `specify` CLI 1.0.5.dev0 installed (`specify check` → "ready to use"). The repo was already initialized with the identical version (`init-options.json` → `speckit_version: 1.0.5.dev0`, zed integration, `feature_numbering: sequential`), and `specify init` refuses to merge without `--force`; per the task's warning not to clobber `.specify/templates` / `.specify/scripts`, re-init was skipped as a no-op-by-configuration. TDD extension v1.1.2 already enabled (`specify extension list` → "✓ TDD Extension").

## Red → Green evidence (deterministic sandbox, fresh per run)

Sandbox = git repo on `master` with `specs/076-prior-feature/` (spec-tree
counter at 076 → next sequential is 077), local branch
`fix/1108-some-bugfix` (models the repo's issue-numbered branch convention),
and the exact invocation from the issue. Full command log in
`tdd/cycle-log.md`; the essential evidence:

**RED (pre-fix script):**

```
$ create-new-feature-branch.sh --json --short-name "make-engine-preset" \
    "Make engine preset (refs issue #1109)"
{"BRANCH_NAME":"1109-make-engine-preset","FEATURE_NUM":"1109"}        # ← the bug
$ create-new-feature.sh --json --dry-run --short-name "make-engine-preset" "…"
{"BRANCH_NAME":"077-make-engine-preset","FEATURE_NUM":"077",…}        # ← the counter to agree with
```

**GREEN (fixed script, same state):**

```
$ create-new-feature-branch.sh --json --short-name "make-engine-preset" \
    "Make engine preset (refs issue #1109)"
{"BRANCH_NAME":"077-make-engine-preset","FEATURE_NUM":"077"}          # ← fixed
$ cat .specify/feature.json
{"feature_number":"077"}                                              # ← emitted as required
branch '077-make-engine-preset' == spec dir 'specs/077-make-engine-preset'   # ← AGREE
```

## Guard evidence (no regressions from the fix)

| Behavior | Result |
|----------|--------|
| Branch-only repo (no `specs/`), exact-name collisions `001-…`/`002-…` exist | allocates `003-…`, never proposes an existing name |
| Explicit `--number 42` | honored (`042-answer`) |
| `--timestamp` | `20260906-102633-ts-test` shape preserved |
| `GIT_BRANCH_NAME=999-custom-name` | exact name used, `FEATURE_NUM` extracted (`999`) |
| `feature.json` merge | pre-existing `feature_directory` preserved, `feature_number` added — verified on both the jq path and the no-jq path (jq hidden from PATH; repeat run updates the value in place) |
| `--dry-run` | computes the name, creates no branch, writes no `feature.json` |
| `bash -n` on the fixed script | clean |

The fix also removed the now-dead number-harvesting helpers
(`get_highest_from_branches`, `_extract_highest_number`,
`get_highest_from_remote_refs`, `check_existing_branches`) so the "never
harvest numbers from ref names" rule is structural. Grep-verified no external
callers (the python/powershell twins carry independent copies and are noted
as follow-up scope in the PR).

## Counts

| Fact | Value |
|------|-------|
| Red tests failed before fix | A1 (branch number 1109 ≠ 077), A2 (no `feature.json` emit), A3 (branch ≠ spec dir) — 3/3 red, exactly as filed |
| Green after fix | A1, A2, A3 pass; guards B1–B6 pass (see `tdd/test-list.md`) |
| `dart analyze lib test` | 0 errors, 0 warnings (103 pre-existing infos, non-fatal) |
| Fast suite (`tools/run_tests_chunked.sh`, foreground ranges over all 90 chunks) | 84 chunks ran, 6 skipped (no fast-tier tests: benchmark, core/dependencies, core/proof, integration, plugins/tdd/scenarios, tdd/077-make-engine-preset) — **3490 tests passed, 0 failed** |
| `dart format .` | fixed 3 pre-existing drift files in `examples/todo_tdd/test/tdd/` (outside the CI gate; committed separately per repo convention `be753fb2`); `dart format --set-exit-if-changed lib test` → 0 changed, exit 0 |
| Mutation gate | not_assessed — the changed files are bash scripts, outside the Dart mutation harness; mutation testing not claimed |

## Success criteria — PROVED vs NOT

- **PROVED**: branch script allocates from the same counter as spec-directory resolution (A1/A3 sandbox evidence above); chosen number emitted into `.specify/feature.json` (A2); `GIT_BRANCH_NAME` escape hatch documented in `.specify/extensions/git/README.md`; `dart analyze` 0 errors; full fast suite 3490/3490 green; formatting clean.
- **NOT claimed**: mutation testing (out of scope for bash); PowerShell/Python twin parity (same latent flaw exists in `create_new_feature_branch.py` and `create-new-feature-branch.ps1` — out of this PR's minimal scope, flagged as follow-up); Flutter-tier tests (SDK not installed, excluded by the prescribed runner).
