# Bug Fix: per-feature TDD artifact namespacing (#827)

- **Slug**: tdd-artifact-namespacing
- **Fixed**: 2026-09-02
- **Assessment**: ./assessment.md
- **Status**: applied
- **Delivered as**: PR #869 (`fix/827-tdd-artifact-namespacing`) — reviewed, extended, verified; squash-merge recommended

## Summary

The flat artifact layout (`test/tdd/<id>_test.dart`, per-feature registries)
made feature N+1's gen collide with feature N's owned files. PR #869
namespaces every generated pair under the feature slug, adds an explicit
`zfa tdd migrate-paths` for legacy projects, and keeps the ownership
guardrail enforced against the namespaced paths. This session reviewed the
PR, found one ship-blocking gap in its migration (the moved test's relative
subject import was never rewritten, so every migrated test stopped
compiling), and delivered the fix as a review change riding in commit
`9211128b` (documented in the PR comment
https://github.com/arrrrny/zuraffa/pull/869#issuecomment-5514406245).

## Changes (final state on the PR branch)

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/commands/gen_command.dart` | modified (PR) | namespaced pair paths + `_validateFeatureSegment`; staleness mirror reproduces the namespaced depth |
| `lib/src/plugins/tdd/commands/migrate_paths_command.dart` | added (PR) + review fix | explicit migration: registry-driven, pair-atomic, `--dry-run`, refuse-on-target, fail-honest missing; review fix added the moved test's import rewrite + cycle-log path rewrite + rollback extension |
| `lib/src/plugins/tdd/commands/run_command.dart` | modified (PR) | pending-with-artifacts disk check: namespaced first, legacy flat fallback (un-migrated projects keep #734v2 deferral semantics) |
| `lib/src/plugins/tdd/services/artifact_registry.dart` | modified (PR) | flat-vs-namespaced mismatch conflicts name `zfa tdd migrate-paths` |
| `lib/src/commands/tdd_command.dart` | modified (PR) | registers `migrate-paths` |
| `test/plugins/tdd/commands/gen_namespacing_827_test.dart` | added (PR) + review fix | coexistence, guardrail, relative import, migrate matrix; review fix added the real-writer-seeded migration regression test |
| `test/plugins/tdd/commands/gen_command_test.dart`, `plan_gen_contract_test.dart`, `sc_017/018/021` | modified (PR) | flat-layout assertions moved to the namespaced layout |

An earlier independent implementation from this session (shared
`TddArtifactPaths` helper, auto-upgrade-on-touch migration, cycle-log
rewrite — all red-first evidenced in `tdd/cycle-log.md` of archived commit
`6b05caab` on local branch `fix/tdd-artifact-namespacing`) was superseded
by the PR-as-base decision; its unique behaviors (import rewrite,
cycle-log rewrite) live on in the review fix.

## Tests Added or Updated

- `gen_namespacing_827_test.dart` — "a REAL generated legacy pair keeps
  compiling after migration" (this session; red-first on the PR branch:
  failed with the flat import in the moved file, green after the fix)
- the PR's own 10-test suite (coexistence, guardrail, import depth,
  migrate ×6) — authored by the parallel session

## Local Verification (this session, on the PR branch)

- `dart test --preset=all test/plugins/tdd/commands/gen_namespacing_827_test.dart` → 11 passed, 0 failed
- `dart test --preset=all test/plugins/tdd/commands/gen_command_test.dart test/plugins/tdd/commands/plan_gen_contract_test.dart` → 24 passed, 0 failed
- `dart analyze` on the touched files → clean
- PR's own broader matrix (fast tier chunked 68/68, slow gen/verify-red/
  make/verify, sc_017/018/021 e2e, tdd.verify PASS_WITH_GAPS with 4/4
  mutants killed) recorded in `evidence.md` / `verification.md`

## Deviations from Assessment

- The assessment's preferred remediation ("auto-upgrade on first run")
  was implemented by the PR as an explicit `zfa tdd migrate-paths`
  command — the issue text allows either; the PR's rationale (opt-in,
  a flat project keeps working) is recorded in `assessment.md` on the
  branch. Accepted.
- Two implementations of the same fix existed momentarily (this session's
  local branch and the PR); per the maintainer's decision the PR was taken
  as the base and the local work archived (`fix/tdd-artifact-namespacing`,
  commit `6b05caab`).
- The review-fix commit `9211128b` also carries unrelated spec-kit
  assessment commits and pubspec.lock churn from a concurrent session
  sharing this working tree; squash-merge at PR time collapses it.

## Follow-ups

- `migrate-paths` should validate its `--feature` flag like gen does.
- gen and run construct the namespaced path inline at two sites — extract
  a shared helper so they cannot drift.
- Consider rewriting `run-state.json` (currently path-free) if it ever
  starts recording paths.
