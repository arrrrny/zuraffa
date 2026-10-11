# Cycle log — Bug 1719 (provider create: `--force`/`--revert` no-ops + duplicate members)

Branch: `fix/1719-provider-force-revert-duplicate-members`
Date: 2026-09-19

## 1. RED — reproduce

- Live CLI repro on a scratch fixture (zuraffa path dependency):
  `zfa service create Auth --params=AuthRequest --returns=User
  --type=usecase --init` → `zfa provider create Auth … --init` → the
  emitted provider carries `Stream<bool> isInitialized(NoParams params)`
  (method) AND `Stream<bool> get isInitialized` (getter),
  `initialize(InitializationParams params)` twice, `dispose(NoParams
  params)` AND `dispose()`; `dart analyze` = 3 × `duplicate_definition`.
- `zfa provider create … --force` on the existing file →
  `⏭ Skipped (use --force to overwrite)` (flag passed, ignored).
- `zfa provider create … --revert` → identical skip; file never deleted.
- `zfa service create Auth … --force` →
  `⚠️ No files were generated (nothing changed). Re-run with --force`.
- Triage (root causes) in `../assessment.md`.
- New regression suite
  `test/fixes/bug_1719_provider_force_revert_duplicate_members_test.dart`
  (B1–B6) run against the unfixed tree: **0 passed / 6 failed** —
  `tdd/red-T001-bug1719.log`.

## 2. GREEN — fix

- Flag plumbing: capability `--revert` forwarding (provider + service),
  per-invocation `force/dryRun/verbose` on the provider fresh-file write
  and the service interface write.
- Member generation: signature-faithful extraction emission (getter stays
  getter; parameter-less stays parameter-less) + init members emitted
  exactly once with extraction dedupe.
- Same command: **6/6 pass** — `tdd/green-T001-bug1719.log`.
- Live CLI re-check: `--force` overwrites (`📝`), `--revert` deletes
  (`🗑`), service `--force` overwrites + conformance pass, service
  `--revert` → `✅ Reverted (deleted):`, regenerated provider analyzes
  clean (`No issues found!`).

## 3. REFACTOR

- None required. `dart format .` → `Formatted 2991 files (0 changed)`
  after absorbing the new test file; analyzer clean on all changed files.

## 4. VERIFY

- Direct suites: provider/service/fixes 93/0, commands 306/0.
- Full fast suite via `tools/run_tests_chunked.sh` (foreground passes,
  kernel caches cleared per chunk): 104 chunks passed, **5092 tests, 0
  failures from this change**; 3 chunks SKIP (no fast-tier tests); 1
  flagged pre-existing failure (`test/cli` → `bug_1360` B1 — verified
  pre-existing via `git stash`).
- Deterministic gate `zfa tdd verify` actually run: `not_assessed`
  (no behavior artifacts registered — bug-flow shape; verbatim report in
  `tdd/verification.md`).
