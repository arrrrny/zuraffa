# Assessment: tdd-make-regression-false-positive (issue #731)

- **Assessed**: 2026-09-02 (this fix session)
- **Severity**: high — `zfa tdd run` deadlocks on already-completed behaviors
- **Input record**: `./issue.md` (GitHub issue #731, sole triage input; the
  `.specify/bugs/<slug>/` records named by the workflow were not present on any
  branch of this repository, so the issue body is the authoritative record)

## Symptom

`zfa tdd make <id>` for a behavior whose test already passes reports
`outcome=regression` (exit 1) when the suite carries pre-existing red behaviors
(deferred acceptance tests). `zfa tdd run` then stops:
`step failed — behavior=U2 step=make outcome=regression`.

## Root cause (verified in this session)

The suite guard (`make_command.dart` step 9, formerly lines ~407-451) diffs the
failing-test identifier sets of two full-suite runs — a pre-make **baseline**
and a post-make **guard** — and reports a regression on ANY identifier present
in the guard but not the baseline:

```dart
if (diff.hasNewFailures) { ... outcome: MakeOutcome.regression ... }
```

`SuiteGuard.diff` matches failing-test identifiers by exact name
(`services/suite_guard.dart`). A pre-existing red behavior's identifier is NOT
stable across two suite runs: a dynamic test name (e.g. a name embedding a
timestamp or generated id) yields a different failing-test identifier in every
run. With a deferred acceptance behavior red in both runs, the guard run's
identifier is absent from the baseline set, `hasNewFailures` fires, and an
already-green target's make is graded `regression` — a false positive that
deadlocks the run loop.

Reproduced deterministically (RED evidence, this session): a fixture sibling
whose failing test name embeds `DateTime.now().microsecondsSinceEpoch` fails
both suite runs with different identifiers; `zfa tdd make` on an already-green
target reported:

```
baseline exit: 1, failed: 1
zfa tdd make: regression detected — 1 NEW failure(s) introduced by the generation:
   - test/a_def_test.dart: deferred acceptance 1788296985218510
make: behavior=B-001 outcome=regression feature=090-tdd-fixture
```

The shape matches the issue's production reproduction exactly (baseline failed: 1,
target green, pre-existing red → `regression`).

## Remediation (implemented)

Scope the regression verdict in `make_command.dart` to failures THIS make can
be held responsible for. A guard failure absent from the baseline by name is a
regression only when:

1. it lives in the current behavior's own test file (the file this make owns), or
2. its file had NO failures at baseline — the whole file was previously green, so
   a red there is a genuine collateral regression (keeps acceptance test A8
   green: sibling file green at baseline → broken by this make → still a
   regression).

Failures confined to a file that was ALREADY red at baseline belong to a
pre-existing red behavior — tolerated regardless of identifier stability, per
the issue's "regardless of other behaviors being red". Tolerated identifiers are
printed with an explicit reason line, and the green-evidence entry records the
scoped verdict (`suiteNewFailures`).

## Constraints honored

- Production changes confined to `lib/src/plugins/tdd/commands/make_command.dart`
  (the regression-check logic). `services/suite_guard.dart` untouched.
- One PR for the bug.
- Existing guard contracts preserved: A8 (collateral sibling regression →
  regression), A9 (pre-existing broken sibling tolerated), U15/U17/A7 (clean
  guard → green entry), issue #694 skip transition.
