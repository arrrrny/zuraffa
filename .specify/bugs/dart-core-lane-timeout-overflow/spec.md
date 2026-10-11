**Template Version**: `zuraffa-1.0`

# Bug Spec: dart_core fast-lane overflow — the pure-Dart CI lane is cancelled at the 30-minute ceiling

**Input**: GitHub issue #1632 — the `dart_core` CI job
(`dart test test --exclude-tags "flutter || e2e"`, `timeout-minutes: 30`) is
cancelled at ~30m14s on every recent run. Run 34951330675 (master,
2026-09-15): 6,962 tests across 1,037 suites completed in 29.5 min and the
runner was killed mid-suite; 57 fast-lane-eligible suites never ran. The lane
absorbed ~116 never-tagged heavyweight suites (subprocess drivers, run-driver
suites, analyzer/compile self-hosting gates) that `dart_test.yaml`'s own
policy assigns to the `slow`/`e2e` tiers. Goal: the `dart_core` test step
below 8 minutes, with a structural pin so the drift cannot recur.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: every fast-lane-eligible `*_test.dart` (carrying no
  `slow`/`e2e`/`flutter` tag in its suite-level `@Tags`) that matches a
  heavyweight criterion MUST carry an exclusion tag: suites that spawn
  external processes (`Process.run`/`Process.start`, the
  `run_zfa_source`/runZfa/`zfa_executable`/`dartTest(` helpers, temp-project
  run drivers) get `e2e` (the #1510 semantics: honest under direct
  `dart test <file>` invocation, excluded from CI's fast lane by the
  B4-pinned selector, still selected by `--preset=all`); in-process slow
  suites (analyzer/compile self-hosting gates, `*_compile_test.dart`,
  CI-proven ≥4s files) get `slow`.
            traces: FastLaneBudgetPin
- **FR-002**: the regression-tier files annotated `@Tags(['regression'])`
  without `slow` MUST become `@Tags(['regression', 'slow'])`, restoring the
  documented invariant that tier suites are default-excluded via `slow`
  (`dart_test.yaml` header; `--preset=regression` coverage unchanged, B1
  still green).
            traces: FastLaneBudgetPin
- **FR-003**: a structural pin test (fast, pure — it reads sources and tags,
  it runs no suites) MUST fail while any fast-lane-eligible file matches the
  heavyweight criteria of FR-001 without an exclusion tag, and pass when the
  census is clean; it must enumerate offenders in its failure reason.
            traces: FastLaneBudgetPin
- **FR-004**: the `dart_core` test step MUST run the residual lane with
  scoped parallelism (`--concurrency=4`) — the global `concurrency: 1` is a
  heavy-lane RAM/disk guard, not a unit-lane requirement — and the step's
  stale "~22 of its 30 budgeted minutes" comment MUST reflect the re-homed
  budget. `dart_test.yaml` selectors stay untouched (B3/B4 unaffected).
            traces: CiDartCoreConcurrency

## Layer Contracts

**Function**:
- `FastLaneBudgetPin`: `census() -> List<String>` — pure scan over
  `test/**/*_test.dart`; parse each file's suite-level `@Tags` annotation; a
  file is fast-lane-eligible iff its tag set is disjoint from
  `{slow, e2e, flutter}`; heavyweight criteria: source matches
  `Process\.run|Process\.start|run_zfa_source|runZfaSource|zfaExecutable|dartTest\(`
  or path matches `_compile_test\.dart|self_hosting`, or the file is in the
  CI-proven ≥4s attribution list recorded in `./assessment.md`; returns the
  eligible-but-untagged offender paths (empty list = fast-lane budget
  respected).
- `CiDartCoreConcurrency`: `stepCommand() -> String` — reads
  `.github/workflows/ci.yaml` and returns the `dart_core` "Dart Test" step's
  `dart test` invocation, which must carry `--concurrency=4` alongside the
  `--exclude-tags "flutter || e2e"` selector.

## Acceptance Scenarios

1. **Given** the pre-fix tree (master `8480a53e`) **When** the FR-003 census
   runs **Then** it reports the untagged heavyweight offenders — including
   `test/commands/dead_positional_grammar_test.dart` (80.1s CI-attributed),
   `test/plugins/tdd/commands/run_driver_timeout_receipt_test.dart` (63.4s),
   `test/templates/self_hosting/*` and the 8 tier-only regression files —
   and the pin test FAILS (RED).
   **Type**: acceptance
2. **Given** the tagged tree (every census offender carrying `e2e` or `slow`,
   regression files `['regression', 'slow']`) **When** the pin test runs
   **Then** it passes with an empty offender list (GREEN) and
   `dart analyze lib test` reports no errors for the annotation edits.
   **Type**: acceptance
3. **Given** the tagged tree **When**
   `dart test test --exclude-tags "flutter || e2e" --concurrency=4` runs
   locally to completion **Then** the residual lane finishes in under 8
   minutes with no failures attributable to the re-tagging (the residual
   contains no census offender by construction).
   **Type**: acceptance
4. **Given** the edited `ci.yaml` **When** `test/tier_integrity_test.dart`
   runs **Then** B1–B4 stay green — the fast-lane `--exclude-tags` selector
   still excludes every `e2e` file and `--preset=all` still selects them.
   **Type**: acceptance
