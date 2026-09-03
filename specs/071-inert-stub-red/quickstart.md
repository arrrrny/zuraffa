# Quickstart: 071-inert-stub-red

Validation scenarios proving inert-stub red end-to-end. All commands run from
the repo root; the fast suite is the default tier (see
`.specify/memory/tdd-profile.md`).

## Prerequisites

- Dart SDK ≥ 3.11 (`dart --version`).
- Dependencies resolved (`dart pub get`).

## 1. Plugin unit/acceptance suite (primary gate)

```bash
dart test test/plugins/tdd/
```

Expected: all pass, including the new acceptance-matrix tests (inert stub →
finder-level red classification; vacuous finders → unexpected-green; throwing
subject → guard-level red; `find.text('X')` pin both ways).

## 2. Static analysis of touched code

```bash
dart analyze lib/src/plugins/tdd/ test/plugins/tdd/
```

Expected: no new issues.

## 3. Focused behavior proofs (fast inner loop while driving the TDD loop)

```bash
dart test test/plugins/tdd/subject_writer_test.dart
dart test test/plugins/tdd/red_classifier_test.dart --plain-name "failing"
dart test test/plugins/tdd/bug_830_widget_subject_kind_test.dart
```

## 4. End-to-end sanity of the verdict surface (optional, no Flutter needed)

The classifier helpers are pure — a transcript fixture containing an authored
finder failure (`Expected: one matching candidate / Actual: <0 with the view
absent>`) classifies `assertion` and yields a named evidence identity:

```bash
dart test test/plugins/tdd/red_classifier_test.dart
```

Full CLI e2e (spawning `zfa tdd gen` + `verify-red` against a fixture project)
follows the existing scenario-test pattern under `test/plugins/tdd/scenarios/`
and runs in the same suite tier.

## Expected outcomes mapped to spec success criteria

- SC-001/SC-004: acceptance-matrix tests show authored finders failing at red
  (observed) then passing against a real view with zero assertion edits.
- SC-002/SC-005: `red-evidence:` line + `evidence=` token name the failing
  assertion; classes remain distinguishable from the summary line alone.
- SC-003: vacuous-finder template against the inert stub classifies
  `unexpected-green` → refused; marker string gate still refuses in `make`.
