# Bug Spec: issue_891 regression test must assert the post-#1206 contract (zero example overrides)

- **Slug**: pr-1210-ci-red
- **Issue**: https://github.com/arrrrny/zuraffa/issues/1211
- **Source**: ./assessment.md (Failure A — master regression from #1206)

## Problem

#1206 (`63ebe917`) deliberately dropped `dependency_overrides: meta: ^1.18.3`
from `example/pubspec.yaml` (Flutter 3.47.x re-pinned meta; resolution is now
proven by `tools/flutter_smoke_gate.sh` / the `flutter_consumer_smoke` CI job).
The regression test `test/regression/issue_891_example_meta_resolution_test.dart`
was not updated and still asserts the override MUST exist, so its tests 1–3 are
red on every tree containing master (`dart_core`: 5381 passed / 3 failed, run
34027280435).

## Required behavior (acceptance criteria)

1. `dart test test/regression/issue_891_example_meta_resolution_test.dart`
   passes on a tree where `example/pubspec.yaml` has NO `dependency_overrides`
   section (the current master shape).
2. Tests 1–3 assert the NEW contract: `example/pubspec.yaml` exists and has no
   `dependency_overrides` section (or at minimum no `meta` entry) — a file-shape
   guard that blocks re-introducing the override silently.
3. Test 4 no longer keys the contract on the analyzer floor (>=13.1.0) heuristic;
   the resolution proof is delegated to `tools/flutter_smoke_gate.sh` /
   `flutter_consumer_smoke`, referenced in the test's doc comment.
4. The issue-#891 history stays in the file's doc comment so the context (why
   the override existed, why it was dropped) is not lost.
5. The test file still guards against `path:` overrides returning (the root
   pubspec prohibition), expressed against the new zero-overrides contract.

## Failing-test scenario (pre-fix)

- Checkout master `350e2d8e` (override absent) → tests 1–3 fail:
  - `example package declares a meta dependency_override (issue #891)` —
    `Expected: <Instance of 'Map'> Actual: <null>`
  - `the meta override floor covers analyzer ≥13.1.0 (meta ^1.18.3)` —
    `type 'Null' is not a subtype of type 'Map<dynamic, dynamic>'`
  - `the meta override is a VERSION override, not a path: override` — same cast error

## Out of scope

- The `engine_check_command_test.dart` failure — that is PR #1210's own
  regression and is fixed on `spec/1109-make-engine-preset` (see ./issue.md).
- Any change to `example/pubspec.yaml` or `tools/flutter_smoke_gate.sh`.
