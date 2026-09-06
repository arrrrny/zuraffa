## Symptom

Master `350e2d8e` (merge of #1206) is red on `dart_core`: **5381 passed / 3 failed** (run 34027280435). The last green master is `c7cf331a` (run 34026515183), i.e. the commit immediately before the #1206 merge.

All 3 failures are in `test/regression/issue_891_example_meta_resolution_test.dart`:

- `example package declares a meta dependency_override (issue #891)` — `Expected: <Instance of 'Map'> Actual: <null>`
- `the meta override floor covers analyzer ≥13.1.0 (meta ^1.18.3)` — `type 'Null' is not a subtype of type 'Map<dynamic, dynamic>'`
- `the meta override is a VERSION override, not a path: override` — same cast error

## Root cause

#1206 (`63ebe917`, fix(1189)) **deliberately dropped** `dependency_overrides: meta: ^1.18.3` from `example/pubspec.yaml` (Flutter 3.47.x re-pinned meta; resolution now proven by `tools/flutter_smoke_gate.sh` / the `flutter_consumer_smoke` CI job) — but did **not update** `test/regression/issue_891_example_meta_resolution_test.dart`, which still asserts the override must exist. The test file is byte-identical pre/post #1206.

The file's own 4th test anticipates this flip ("flip this guard then") but keys the condition on the analyzer floor dropping below 13.1.0 — the actual drop trigger was the Flutter meta re-pin + #1189, so the coded condition never flipped.

## Expected

dart_core green on master; the 891 regression test asserts the NEW contract (zero dependency_overrides in `example/pubspec.yaml`, resolution proof delegated to the smoke gate).

## Suggested fix

Rewrite `test/regression/issue_891_example_meta_resolution_test.dart`:

1. Tests 1–3 → assert `example/pubspec.yaml` has **no** `dependency_overrides` (file-shape guard stays in dart_core).
2. Test 4 → drop/flip the analyzer-floor heuristic; point at `tools/flutter_smoke_gate.sh` as the resolution proof.
3. Keep the issue-#891 history in the doc comment so the context isn't lost.

## Blast radius

Also currently fails every open PR's merge-ref CI run (e.g. #1210 shows the same 3 failures on top of its own separate `engine_check_command_test.dart` regression — that one belongs to the PR, not master).
