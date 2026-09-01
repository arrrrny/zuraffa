---
feature: test-package-missing-after-setup
loop: inside-out
profile: .specify/memory/tdd-profile.md
spec_criteria: 4
planned_at: fffd50ad
updated_at: fffd50ad
suite_baseline: green
---

# Test List: test package missing from dev_dependencies after zfa setup (bug #716)

A pure library change (a Dart map inside
`lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart`): no
user-visible UI surface of its own, so the loop is inside-out. The outer-loop
acceptance evidence is the end-to-end `zfa setup` → `zfa tdd gen` →
`flutter test` reproduction captured in `evidence/`.

## Outer loop: acceptance behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| A1 | A fresh `zfa setup` Flutter project has `test: ^1.0.0` in the generated pubspec `dev_dependencies` and a `zfa tdd gen` test importing `package:test/test.dart` compiles under `flutter test` (honest-red assertion only) | AC-1, AC-2 | example | DONE | `evidence/red-e2e.md` (red) + `evidence/green-e2e.md` (green), captured in-session on a scratch project |

## Inner loop: unit behaviors

### `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart`

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U1 | `flutterDevDependencies` includes `test: ^1.0.0` (the template the setup writer and tdd init writer both consume) | AC-1 | example | DONE | `test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart::flutterDevDependencies includes test ^1.0.0` |
| U2 | Flutter-mode `ensure()` adds `test` to a pubspec whose `dev_dependencies` lack it, preserving `flutter_test` alongside | AC-1, AC-2 | example | DONE | `test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart::flutter-mode ensure adds test to a fresh Flutter pubspec` |
| U3 | Flutter-mode `ensure()` does not duplicate an existing `test` entry | AC-3 | example | DONE | `test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart::flutter-mode ensure does not duplicate an existing test entry` |
| U4 | Dart-mode contract unchanged: `dartDevDependencies` keeps `test: ^1.25.0`, flutter_test absent from Dart projects | AC-4 | example | DONE | `test/cli/writers/tdd/pubspec_dev_dependencies_patcher_test.dart::dartDevDependencies includes test ^1.25.0` + `::dart-mode ensure adds test (and no flutter_test) to a Dart project` |

## Invariants and edge cases still to place

None: the patcher's other paths (parse failure misfire-stop, inline mapping
rejection, missing block creation) are covered by pre-existing tests
unchanged by this fix and out of the bug's scope.

## Out of scope

- `zfa tdd gen`/`zfa tdd make` test templates: hard constraint — do not
  modify test templates; the templates are correct, the pubspec template was
  wrong.
- `package_scaffold.dart` dev_dependencies (its own template for
  `zfa package` projects): separate surface, not reported by issue #716.
- Version-pinning `test` above `^1.0.0` for Flutter projects: the issue
  explicitly expects `test: ^1.0.0`; pub resolves it to a version sharing
  `test_api` with `flutter_test` (verified: test 1.31.1 + test_api 0.7.12).

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md`:

- Single test: `dart test <file> --plain-name "<name>"`
- Whole file: `dart test <file>` (this file is tagged `slow`: run with
  `dart test --preset=all <file>`)
- Full suite: `dart test` — slow; run the scoped subset for feature work
- Mutation: none wired; deliberate-mutant sampling per the rubric
