**Template Version**: `zuraffa-1.0`

# Feature Specification: 1395-day-zero-module-deps — the day-zero app module declares its deps

VERIFY misfire (GitHub issue #1395, priority high): the zfa-generated
day-zero app module (`lib/app.dart`, spec 041 FR-001 / issue #626) imports
`package:zuraffa_flutter/zuraffa_flutter.dart` and uses `GetIt`, but the
day-zero writer pass that emits the module did not declare those runtime
deps in the consumer pubspec — the tree never compiled cleanly, and the
acceptance composition refused.

## Problem

`zfa tdd init` / `zfa setup` write the day-zero app module into the
CONSUMER package. The generated source imports
`package:zuraffa_flutter/zuraffa_flutter.dart` and exposes a `GetIt`
registry (`final GetIt di = GetIt.instance`). When the writer pass does not
declare `zuraffa_flutter` + `get_it` under `dependencies:` in the SAME
pass, the consumer tree analyzes red out of the box:

```
terminal build step failed with 3 analyzer error(s) ...
   error - app.dart:25:9 - Undefined class 'GetIt' - undefined_class
   error - app.dart:25:20 - Undefined name 'GetIt' - undefined_identifier
   info  - app.dart:10:8 - The imported package 'zuraffa_flutter' isn't a dependency of the importing package - depend_on_referenced_packages
❌ dart analyze reported 3 error(s) ... generated code does not compile cleanly.
```

Consequences observed on issue #1395:

1. The example tree never compiled cleanly since init ran — every
   `zfa tdd run` baseline reported "2 pre-existing failure(s)".
2. A2's phase-2 composition (`zfa build`) hit the #942 build gate
   (`verifyAnalyzeOrFail` refuses on error/warning severity) and refused —
   the engine lane could never complete its acceptance half.

## Gap classification

Missing dependency: the day-zero writer emits code requiring undeclared
deps. The `zfa tdd init` self-heal (`TddBaselineInit` →
`PubspecAppDependenciesPatcher`, issue #1349) covers the init path; the
`zfa setup` day-zero baseline emission (`_emitTddBaseline`) writes the SAME
module in ITS pass without running that self-heal — the remaining gap.

## Remediation

The day-zero writer pass that emits `lib/app.dart` must declare
`zuraffa_flutter: ^6.0.0` + `get_it: ^9.2.1` under `dependencies:` in the
same pass, idempotently (skip-if-declared, hand-edit preserving, additive
when the DependencyWirer already declared one of the pair) — reusing the
#1349 self-heal. Regression gates: a fresh Flutter consumer tree analyzes
with 0 errors after init/setup; re-runs never duplicate deps.

## Requirements

- **FR-001**: The system SHALL declare the day-zero app module's runtime
  dependencies (`zuraffa_flutter`, `get_it`) under `dependencies:` in the
  SAME pass that writes `lib/app.dart`.
      traces: PubspecAppDependenciesPatcher
- **FR-002**: The self-heal SHALL be idempotent: a re-run (setup after
  init, or a second pass) adds nothing and never duplicates a declared
  entry.
      traces: PubspecAppDependenciesPatcher.ensure

## Acceptance Scenarios

1. **Given** a fresh Flutter consumer **When** the day-zero writer pass runs (setup or tdd init) **Then** `dart analyze lib` reports 0 errors (the #942 gate severity contract) and `flutter test` is green
   **Type**: acceptance

2. **Given** a consumer pubspec that already declares one of the pair **When** the self-heal runs **Then** only the still-missing entries are added, under `dependencies:`, never duplicated
   **Type**: unit

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, U1]
    flutter_allowed: false
```
