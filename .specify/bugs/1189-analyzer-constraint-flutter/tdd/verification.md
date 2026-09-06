# TDD Verification — Issue #1189 (analyzer constraint breaks Flutter consumers)

- Date: 2026-09-06
- Toolchain: Flutter 3.47.2 (stable) / Dart 3.13.2, Linux x86_64
- Branch: `fix/1189-analyzer-constraint-flutter`
- Engine detection: `zfa` CLI is wired in this repo but `.zfa.json` is
  absent at the root, so per `.specify/extensions/tdd/commands/speckit.tdd.verify.md`
  Step 0 this audit ran the documented **fallback path** (LLM-guided,
  evidence-first) instead of `zfa tdd verify`. Every verdict below is
  backed by a captured command + exit code; nothing is asserted without
  a logged run.

## Verdict: PASSED (for the scope of this bug)

All success criteria defined in `spec.md` are PROVED except where
explicitly marked NOT PROVED below (none for BR-1..BR-5; one
sub-check — whole-tree formatting — is reported with a scoped caveat
that does not affect the bug's acceptance criteria).

## Gate evidence

| # | Check | Command | Result | Proves |
|---|-------|---------|--------|--------|
| 1 | RED — Flutter consumer fails on pre-fix tree | `flutter pub get` in `example/` (HEAD, stashed fix) | **exit 1** — `zuraffa from path is incompatible with flutter_test from sdk` (`red-evidence-flutter-pubget.md`) | Bug reproduced |
| 2 | RED — smoke gate fails on pre-fix tree | `tools/flutter_smoke_gate.sh` (HEAD, stashed fix) | **exit 1** — stage-1 FAIL message (`gate-red-evidence.md`) | Gate non-vacuous (BR-5) |
| 3 | GREEN — committed Flutter consumer resolves | `flutter pub get` in `example/` | **exit 0** — `Got dependencies!`, zero overrides | BR-1, BR-2 |
| 4 | GREEN — root pub get recursing into example/ | `dart pub get` | **exit 0** — `Got dependencies in ./example` | BR-2 |
| 5 | GREEN — tiny core+flutter_test app, zero overrides | gate stage 2 (synthesized app, `zuraffa 6.1.0 from path` in graph) | **exit 0** | BR-1 |
| 6 | GREEN — public surface compiles + runs under flutter_test | gate stage 3: `flutter test --reporter compact` | **exit 0** — `00:00 +1: All tests passed!` | BR-3 |
| 7 | Widened lower bound honest | TEMP local `dependency_overrides: analyzer: 14.0.0` (never committed) + `dart pub get` + `dart analyze lib test` | **exit 0** | BR-4 |
| 8 | Analyzer info parity vs pre-fix baseline | `dart analyze lib test` | **exit 0, 103 issues** — identical count to the 103-info pre-fix baseline (naive fix had produced 218; the analysis_options ignore restores parity) | BR-4 |
| 9 | Fast-suite regression backstop | `tools/run_tests_chunked.sh` fast tier via `run_chunks_range.sh` (90 chunks, kernel caches bounded per chunk; background reaping forced batched ranges — log is cumulative) | **0 failed chunks**; 84 chunks `All tests passed`, 6 chunks SKIP (no fast-tier tests, exit 79 path), **3490 tests passed, 0 failed** (`fast-suite-chunked-run.md`) | BR-4 backstop |
| 10 | Formatting (CI gate scope) | `dart format --output=none --set-exit-if-changed lib test` | **0 changed** (2210 files scanned) | CI format job green |
| 11 | Whole-tree formatting (informational) | `dart format --output=none --set-exit-if-changed .` | 3 files flagged — `examples/todo_tdd/test/tdd/{a1,u1,u3}_test.dart` — **pre-existing on master**, outside the CI format gate (`lib test`), untouched by this PR; left as-is to keep the diff minimal | reported honestly |

## Mutation phase

Not applicable to this fix: no shipped Dart code changed (pubspec
metadata, lint config, CI wiring, records only). `mutation-test.xml`
scopes mutations to the feature-041 TDD plugin + writers, none of which
this PR modifies. A mutation run over an unchanged surface would prove
nothing; skipped rather than faked.

## Test-first discipline

- The bug was reproduced (RED) against the unmodified HEAD tree BEFORE
  the fix was applied (solver failure + gate exit 1), matching
  `tdd/test-list.md` T1/T4-pre.
- The gate added in this PR is itself regression-tested in both
  directions (fails on pre-fix pubspec, passes on fixed pubspec) — it
  is a test that demonstrably tests the bug.

## Residual risks

- The repo-wide `depend_on_referenced_packages: ignore` is broader than
  ideal (see assessment.md Risks); accepted with rationale.
- Whole-tree formatting drift in `examples/todo_tdd/**` predates this
  PR and is invisible to the CI format gate; flagged for a future
  housekeeping change, not smuggled into this bugfix.

## Verdict lines

- tdd/verification.md: gate **passed** (11 checks: 10 PROVED green, 1
  informational with pre-existing-drift caveat).
- Flutter-consumer smoke gate: **green** on the fixed tree, **red** on
  the pre-fix tree (proves both the fix and the gate).
