# Verification — 1530-generated-code-fails-own-gate

**Branch**: `feat/1530-generated-code-fails-own-gate` | **Dart SDK**: 3.13.3 | **Date**: 2026-09-13

Red evidence: `tdd/red-evidence.md`. Every behavior below went RED before
its implementation went GREEN (runs recorded in red-evidence.md); this
file records the green state and the regression sweep.

## Behavior green evidence

| id | behavior (spec) | test | result |
| -- | --------------- | ---- | ------ |
| A1 / U1 (FR-001, FR-004) | unresolved barrel → hide combinator dropped; generated local/remote/mock emissions carry NO `hide Task, TaskPatch` | `test/utils/zuraffa_barrel_exports_test.dart` (`unresolved → the hide combinator is dropped entirely`), `test/plugins/datasource/barrel_hide_unverified_1530_test.dart` (3 emission probes) | PASS (12/12 + 3/3 after fix) |
| A2 / A4 (FR-002 seeded path, FR-010) | verified hides kept, unverified dropped; #942 collision case preserved | `zuraffa_barrel_exports_test.dart` (`hides are filtered…`, `names the barrel does not export are dropped`, `exported colliding names are kept`) | PASS |
| A3 (FR-002) | `show` contributes only shown names; `hide` subtracts; unqualified lines unchanged | `zuraffa_barrel_exports_test.dart` combinator-aware group (4 tests) | PASS |
| A3-adjacent (FR-003) | nested directory-relative barrel name verifies | `zuraffa_barrel_exports_test.dart` nested group | PASS |
| A5 (FR-005) | ensure adds `zuraffa: ^6.0.0` under `dependencies:` | `test/core/dependencies/pubspec_zuraffa_ensure_test.dart` (A-1530-5) + e2e `test/commands/make_pubsync_zuraffa_ensure_test.dart` (A-1530-5-e2e) | PASS |
| A6 (FR-006) | idempotent — byte-identical re-run | `pubspec_zuraffa_ensure_test.dart` (A-1530-6) + e2e (A-1530-6-e2e, exactly one declaration) | PASS |
| A7 (FR-006) | comments/blank lines/order preserved | `pubspec_zuraffa_ensure_test.dart` (A-1530-7) | PASS |
| A8 (FR-005) | inline mapping refused; unparseable YAML refused; override-only still declared | `pubspec_zuraffa_ensure_test.dart` (A-1530-8a/8b/8c) | PASS |
| A9 (FR-007) | no `package:zuraffa` imports → pubspec untouched | `pubspec_zuraffa_ensure_test.dart` (A-1530-9) | PASS |
| A10 (FR-008) | gwfb receipt prints `warning -` lines verbatim | `test/plugins/tdd/make_command_test.dart` (A-1530-11) | PASS |
| A11 (FR-008) | no-warnings line when output carries none | `make_command_test.dart` (A-1530-12) | PASS |
| A12 (FR-009) | errors in build output keep the #942 `generation-error` refusal; grading untouched | `make_command_test.dart` bug-737 errors-not-tolerated test + `test/plugins/tdd/bug_1407_make_gate_errors_only_test.dart` (8/8) | PASS |
| A5-e2e receipt | make receipt names the ensured declaration | `make_pubsync_zuraffa_ensure_test.dart` | PASS |
| #1265/#1190 contract migration | `zuraffa` excluded from the pub-add line (ensured instead), even offline; json `auto_added_pubspec_deps` carries it; ⚠️ diagnostic remains for the other packages | `test/commands/make_pubspec_auto_add_test.dart` (3/3), `test/commands/make_pubspec_sync_test.dart` (4/4) | PASS |

## Real-CLI probe (T022, the issue's exact failure shape)

Fresh fixture target (pubspec WITHOUT `zuraffa`, entity `Task` present):

```
$ zfa entity create -n Task --field title:String --auto-id
$ zfa make Task datasource --with mock
✅ Ensured zuraffa: ^6.0.0 in pubspec.yaml dependencies — generated files import package:zuraffa (issue #1530). Run pub get to re-resolve.
$ grep -rn "hide " lib/src/            → (no matches)
$ grep -n zuraffa pubspec.yaml         → 10:  zuraffa: ^6.0.0
```

Pre-fix the same probe emitted `import 'package:zuraffa/mock.dart' hide
Task, TaskPatch;` + 2x `hide Task, TaskPatch` (the issue's 4x
`undefined_hidden_name`), and `zuraffa` reached the pubspec only through
a network `pub add` (offline → the `depend_on_referenced_packages` class
this spec fixes).

## Regression sweep (SC-005)

| lane | result |
| ---- | ------ |
| `test/utils/` (barrel exports, entity utils) + `test/core/` + `test/cli/writers/tdd/` + datasource | 685 passed, 0 failed |
| `test/commands/` (full lane incl. migrated #1265/#1190 pins) | 372 passed, 0 failed |
| `test/plugins/{mock,repository,usecase,provider}/` | 303 passed, 0 failed |
| `test/plugins/tdd/make_command_test.dart` (`--preset=all`) | 35 passed; 5 failures are PRE-EXISTING and identical to the unmodified baseline (bug 829 U-829g/U-829h, spec 052 A10/A11/A15 — environment-dependent heavy integration tests; failure sets diffed byte-identically against `git stash` baseline) |
| `test/plugins/tdd/bug_1407_make_gate_errors_only_test.dart` (`--preset=all`) | 8 passed — the #1407 gate contract is unchanged |

## Static analysis + formatting (hard constraints)

- `dart analyze` over every branch-changed file (`git diff --name-only origin/master...HEAD -- '*.dart'`):
  **1 issue — the pre-existing `prefer_collection_literals` info** in
  `lib/src/commands/make_command.dart` (present at base line 1850; shifted
  to 1920). **Zero new warnings.**
- `dart format --set-exit-if-changed --output=none` over all touched files:
  exit 0 (clean).
- Untouched by design (FR-009): `zfa build`'s analyze gate
  (`build_command.dart`), the analysis server, the state machine
  (`generation_plan.dart` outcomes), `step_runner.dart` grading, and the
  #942/#737/#1407 tolerance semantics — the receipt change is print-only.

## Success criteria scoreboard

- **SC-001** PASS — probe grep: no `hide Task, TaskPatch` anywhere (A1).
- **SC-002** PASS — combinator-aware + nested-relative verification (A3).
- **SC-003** PASS — textual offline ensure + idempotent re-run (A5/A6).
- **SC-004** PASS — verbatim warnings block + explicit no-warnings line (A10/A11).
- **SC-005** PASS — regression sweep green; seeded-path emission unchanged (A4, FR-010).
