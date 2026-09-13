# Tasks: dart format Robustness in a Fresh Clone [SPEC 1506]

**Feature ID:** 1506-format-fresh-clone-robustness
**Issue:** #1506

MVP-first: behaviors (FR-1..FR-3) ship as the red-green-refactor loop
below; non-behavioral tasks (docs, spec bookkeeping) follow. Every
behavior has a failing test before its implementation (TDD extension
contract).

## Phase A — Behaviors (TDD, red → green → refactor)

- [x] T001 (TDD, red) Write `test/commands/format_runner_1506_test.dart`
  covering the FormatRunner behavior list (see
  [tdd/test-list.md](tdd/test-list.md) U1–U6). Run → record RED
  evidence in [tdd/cycle-log.md](tdd/cycle-log.md).
- [x] T002 (green) Implement `lib/src/core/format/format_runner.dart`:
  `FormatProcessRunner` typedef (PubspecProcessRunner convention),
  `FormatRunResult` (formatRan, pubGetRan, skipped, exitCode, warning),
  `FormatRunner.formatPaths` with resolution check → pub-get
  enforcement → scoped `dart format`. Run T001 → GREEN.
- [x] T003 (TDD, red) Write
  `test/commands/entity_format_scope_1506_test.dart`: in-process
  `EntityCommand.execute(['create', ..., '--dart-format'])` with
  injected recording FormatRunner — format scope is
  `lib/src/domain/entities`, never `.`; pub get precedes format when
  the fixture has no package config. Run → RED.
- [x] T004 (green) Wire `EntityCommand` to `FormatRunner`: constructor
  injection (`formatRunner`), `_runFormat()` delegates with scope
  `[fixedEntityOutput]`, surfaces the single warning when present.
  Run T001+T003 → GREEN.
- [x] T005 (refactor) Reviewed duplication: the two recorders stay
  separate deliberately — the unit-test fake simulates the pub-get
  side effect (writes the package config) while the integration fake
  records across both seams; a shared helper would couple unrelated
  fixtures. Re-ran T001+T003: green.

## Phase B — Non-behavioral (enforcement surface)

- [x] T006 AGENTS.md hard rule: enforce `dart pub get --no-example`
  before every formatter invocation (fresh-clone guard) — FR-4.
- [x] T007 `.github/agents/surgical-pr-fix.agent.md`: pub-get
  precondition added to the `dart format <touched files>` verify step —
  FR-4.
- [x] T008 CI note: verify `.github/workflows/ci.yaml` format job order
  (already `pub get --no-example` → `format --set-exit-if-changed`);
  record as verified-no-change in verification.md — FR-4.

## Phase C — Verification

- [x] T009 Targeted lanes: `dart test
  test/commands/format_runner_1506_test.dart
  test/commands/entity_format_scope_1506_test.dart` green (8/8).
- [x] T010 `dart analyze lib test` — zero new issues vs baseline
  (0 errors / 112 pre-existing infos).
- [x] T011 `dart format` on every touched file (idempotence check) +
  full-suite spot: `dart test test/commands/` green (378 tests).
- [x] T012 Write [tdd/verification.md](tdd/verification.md): test-first
  evidence, smell rubric, acceptance-criteria coverage.
