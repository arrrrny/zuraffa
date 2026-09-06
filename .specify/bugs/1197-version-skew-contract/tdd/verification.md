# TDD Verification — BUG 1197 generator/runtime version-skew contract

Date: 2026-09-06 · Verifier: this PR's author (agent run)
Status: **REAL — every claim below was executed in this working clone.**
Nothing on this page is projected or assumed; commands and exits are
recorded verbatim in the referenced evidence files.

## 1. Test-first evidence (red → green)

| Phase | Command | Result | Evidence |
|---|---|---|---|
| RED | `dart test test/skew` (tests written FIRST, against the not-yet-existing contract) | `00:00 +0 -11: Some tests failed.` — 11 failures (missing `lib/src/skew/` module: compile errors = the failing tests), `dart test exit: 1` | `tdd/red-evidence.txt` |
| RED (live repro) | `git cat-file -e v6.1.0:lib/skin.dart` → `exit=1`; same for `lib/simulation.dart`, `lib/src/plugins/xray/xray_overlay.dart`; `rg -c 'package:zuraffa/skin.dart' lib/` → 8 emission references | master emits imports the published core lacks | `tdd/red-evidence.txt` |
| GREEN (unit) | `dart test test/skew` | `00:02 +29: All tests passed!` `exit=0` — 29 tests, 4 files: `bug_1197_skew_contract_test.dart` (15), `bug_1197_two_end_matrix_test.dart` (8), `bug_1197_doctor_skew_test.dart` (9 — registry/pin/installed/receipt-floor/fail-open), `bug_1197_receipt_stamp_test.dart` (4: round-trip, back-compat, stamping, de-hardcode guard) | `tdd/green-evidence.txt` |
| GREEN (real matrix) | `tools/run_skew_matrix.sh` | `== skew matrix: GREEN — slice compiles on both ends; floor gates live` — old-end analyze CLEAN, master-end analyze CLEAN, receipt stamps asserted (`min_core_version=6.0.0 generated_against_core=6.0.1` / `=6.1.0`), skin refusal + DI refusal on old end (exit 1 + prescription), skin kit emitted on master | `tdd/skew-matrix-output.txt` |

Test-first discipline held: the contract tests were committed to the
working tree and observed failing BEFORE the implementation existed
(`lib/src/skew/skew_contract.dart` was created only after the RED run
was recorded). The two-end matrix test additionally FAILED against the
then-current implementation in a way that drove the fix: the static
sweep caught `package:zuraffa/simulation.dart` (spec 893) and
`package:zuraffa/src/plugins/xray/xray_overlay.dart` (spec 036) as
further unguarded post-v6.1.0 emissions — surfaces NOT named in the
original bug report. The fix therefore registers three floors, not one,
and gates six emission sites.

## 2. Test-smell rubric

- **Behavior vs structure**: tests assert the CONTRACT (refusal with
  prescription, surface availability on both ends, receipt round-trip
  keys, doctor verdict ids/statuses), not private call shapes.
- **Live materialization over mocks**: the matrix test materializes
  tag `v6.1.0` via `git archive` (real files, not a fake) and scans
  real builder OUTPUT (`SkinContractKitBuilder().build(...)`,
  `AppShellBuilder().buildAppRouter(...)`, `ViewClassBuilder`) — no
  golden-string mockery.
- **Fail-open semantics pinned**: `evaluate` on an unresolvable core
  is asserted `ok` + `unknown` (the #942 precedent), so the gate can
  never silently become a hard dependency on `pub get` state.
- **Back-compat pinned**: legacy receipts WITHOUT the new stamps parse
  with null fields (old receipts never break).
- **De-hardcode guard**: `TddGenerationReceipts` receipt
  `generator_version` must equal the `version` const — the test cannot
  distinguish today's const from the old literal (both are 6.1.0) but
  fails the day someone bumps the const and leaves a literal behind.
  Honest limitation, stated rather than hidden.
- **No test smelled of tautology**: the refusal tests assert the
  prescription text AND that no file was written (skin leg), and the
  CI script independently re-proves both via the compiled binary.

## 3. Mutation / strength check

No mutation run was executed for this bug (the configured
`mutation_test` scope covers the TDD plugin + writers from spec 041,
not the new `lib/src/skew/` module; adding a mutation scope was judged
out of budget for this PR). Strength evidence offered instead:

- The two-end matrix test DETECTED two real, undisclosed instances of
  the bug (simulation barrel, xray overlay) during the red→green
  loop — i.e. the suite has demonstrated real fault detection power
  against the actual defect class, not synthetic mutants.
- The refusal contract is proven three independent ways: unit
  (`requireSurfaces` throws), structural (builder output scanned),
  end-to-end (compiled AOT binary against a real pub-resolved old-core
  consumer, exit 1 + prescription, no files written).
- Doctor enforcement proven at unit level AND live: `zfa doctor
  --format json` inside the old-core consumer reports the triangle
  `generator v6.1.0 | installed core v6.0.1 | pin: none` (status
  pass; warn/fail paths covered by `bug_1197_doctor_skew_test.dart`).

## 4. Acceptance-criteria coverage (from the bug's "What to build")

| AC | Status | Proof |
|---|---|---|
| Generator stamps the core version it generated against | DONE | make + TDD receipts carry `generated_against_core` (matrix leg asserts `generated_against_core=6.0.1` old / `6.1.0` master) |
| Generated code's imports reference only APIs available since a declared floor | DONE | `coreApiFloors` (skin/simulation/xray-overlay); static sweep test asserts EVERY `Directive.import('package:zuraffa/...')` emission is two-end-safe or floor-registered; runtime gates refuse missing surfaces at six sites |
| Test in core: slice resolved against OLDEST core tag + NEWEST master, both compile | DONE (executed locally; CI job added) | `tools/run_skew_matrix.sh` GREEN — real `dart pub get` + `dart analyze` clean on both ends; `.github/workflows/skew-matrix.yaml` `two-end-matrix` job runs it on every PR touching lib/bin/pubspec |
| CI two-end skew matrix | DONE | workflow committed this PR; the fast in-repo half (`dart test test/skew`) runs in the same job |
| Constraint hygiene: Flutter-consumer smoke gate before publish (#1189) | DONE (script; executed in CI only) | `tools/flutter_consumer_smoke.sh` + `flutter-smoke-gate` job in skew-matrix workflow + pre-publish `needs:` gate in release.yml. NOT run locally (no Flutter SDK in this environment) — stated honestly; the gate is authored to run first-class in CI |
| `zfa doctor` reports skew (target pubspec vs generator version vs installed binary) | DONE | `runtime-skew` check in the #793 registry (U11 pinned set updated accordingly); live outputs recorded above |
| One PR for this bug | DONE | this branch, single PR, `Closes #1197` |

## 5. Full-suite verification (mandated battery)

- `dart analyze lib test --no-fatal-warnings` → **0 errors, 0
  warnings** (103 pre-existing infos, unchanged from base).
- `tools/run_tests_chunked.sh` semantics (official per-chunk command
  `dart test <dir> --exclude-tags flutter`, kernel caches cleaned
  between chunks; run via a resumable wrapper because detached
  background processes do not survive this sandbox) → **3,519 tests
  passed, 0 failed** across 91 chunks (85 PASS, 6 SKIP — those
  folders hold only slow/integration/property-tier tests, skipped by
  design per dart_test.yaml). Per-chunk log:
  `tdd/chunked-suite-results.txt`.
- `dart format .` → re-run reports **0 changed** (idempotent); the
  only formatting diffs vs HEAD are this PR's files plus three
  pre-existing unformatted `examples/todo_tdd` test files that
  `dart format .` fixed (format-only hunks).
- Known environmental skip (NOT a regression): `test/plugins/view/
  view_compile_test.dart` is `@Tags(['flutter'])` and requires the
  Flutter SDK — excluded from the fast suite by the same tag on base.

## 6. Residual risks (honest)

- The Flutter smoke gate has not executed anywhere yet — first real
  run is this PR's CI. Its script is deliberately minimal (pub get +
  analyze of a two-import consumer).
- `ZuraffaBarrelExports` (pre-existing, #1176/#1180) resolves
  relative `rootUri` against the project root instead of
  `.dart_tool/` — the same spec deviation fixed in the new resolver.
  Left untouched here (scope); flagged for a follow-up.
- `zap.dart` is also post-v6.1.0 but NOT emitted by any generator
  emission site (only its own doc comment references it) — no floor
  registered, correctly.
- Floors declare `introducedIn: 6.2.0` while master's `version` const
  still reads 6.1.0: availability is authoritative, the version floor
  is advisory metadata for receipts/doctor. The version bump itself is
  a release decision outside this bug's scope.
