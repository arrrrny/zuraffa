# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: 0971-route-A1 (red)

- behavior: 0971-route-A1
- kind: red
- classification: assertionFailure
- criterion: Order 1
- test: test/plugins/route/spec_971_t001_dead_methods_flag_test.dart
- command: `dart test test/plugins/route/spec_971_t001_dead_methods_flag_test.dart`
- exit: 1
- at: 2026-09-04T20:44:40.043382Z
- output:
```
00:00 +3 -1: Some tests failed.

Failing tests:
  test/plugins/route/spec_971_t001_dead_methods_flag_test.dart: spec 0971 T001: dead --methods flag deleted from zfa route zfa route --help no longer advertises --methods
```

- schema: 1
- prev-hash: genesis
- hash: 71cbd73a76ddbab21f95512b5f1903b327595f86d0672335a37881a9fcc61171

## Cycle: 0971-route-A1 (green)

- behavior: 0971-route-A1
- kind: green
- criterion: Order 1
- test: test/plugins/route/spec_971_t001_dead_methods_flag_test.dart
- command: `dart test test/plugins/route/spec_971_t001_dead_methods_flag_test.dart`
- exit: 0
- at: 2026-09-04T20:44:42.821537Z
- output:
```
00:00 +0: loading test/plugins/route/spec_971_t001_dead_methods_flag_test.dart
00:00 +0: spec 0971 T001: dead --methods flag deleted from zfa route zfa route --help no longer advertises --methods
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 71cbd73a76ddbab21f95512b5f1903b327595f86d0672335a37881a9fcc61171
- hash: 39d0895f5c7f644696fc0584c2703a81ba27defce0ec3aec694945ccd4a22655

## Cycle: 0971-route-U1 (red)

- behavior: 0971-route-U1
- kind: red
- classification: assertionFailure
- criterion: Order 2
- test: test/plugins/route/spec_971_t002_create_json_envelope_test.dart
- command: `dart test test/plugins/route/spec_971_t002_create_json_envelope_test.dart`
- exit: 1
- at: 2026-09-04T20:44:40.043382Z
- output:
```
00:00 +0 -6: Some tests failed.

Failing tests: all six envelope tests — "no JSON envelope found in CLI
output" (`zfa route create Product --json` was then a dispatch-level
usage error: --json did not exist as an output flag).
```

- schema: 1
- prev-hash: genesis
- hash: 9c08698f502babd1d772453867e50ce22d93b0d9a9decb68a038beaf61a31f8b

## Cycle: 0971-route-U1 (green)

- behavior: 0971-route-U1
- kind: green
- criterion: Order 2
- test: test/plugins/route/spec_971_t002_create_json_envelope_test.dart
- command: `dart test test/plugins/route/spec_971_t002_create_json_envelope_test.dart`
- exit: 0
- at: 2026-09-04T20:44:45.927263Z
- output:
```
00:00 +0: loading test/plugins/route/spec_971_t002_create_json_envelope_test.dart
00:00 +0: spec 0971 T002: route create --json envelope schema emits {routes[], deepLinks, schemeRegistrations, routeTableTestPath, schema:1}
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 9c08698f502babd1d772453867e50ce22d93b0d9a9decb68a038beaf61a31f8b
- hash: 6625ae638b28ca7595a93df2548b8526bb4eaa8b62a031e3abf79be36d2a3031

## Cycle: 0971-route-U2 (red)

- behavior: 0971-route-U2
- kind: red
- classification: assertionFailure
- criterion: Order 3
- test: test/plugins/route/spec_971_t003_routes_receipt_test.dart
- command: `dart test test/plugins/route/spec_971_t003_routes_receipt_test.dart`
- exit: 1
- at: 2026-09-04T20:44:40.043382Z
- output:
```
00:00 +1 -3: Some tests failed.

Failing tests:
  spec 0971 T003: routes receipt via ReceiptStore fresh route create writes .zfa/receipts/routes-Product.json
  spec 0971 T003: routes receipt via ReceiptStore the receipt carries the route-table test path AND its hash
  spec 0971 T003: routes receipt via ReceiptStore zfa proof check turns red on a hand-edited route file
(the "green on fresh create" test passed vacuously — no receipts existed at all)
```

- schema: 1
- prev-hash: genesis
- hash: 1776a796466961a1a0be2a8d09b48e56304bc4a063df483058e65f523c458aed

## Cycle: 0971-route-U2 (green)

- behavior: 0971-route-U2
- kind: green
- criterion: Order 3
- test: test/plugins/route/spec_971_t003_routes_receipt_test.dart
- command: `dart test test/plugins/route/spec_971_t003_routes_receipt_test.dart`
- exit: 0
- at: 2026-09-04T20:44:49.170843Z
- output:
```
00:00 +0: loading test/plugins/route/spec_971_t003_routes_receipt_test.dart
00:00 +0: spec 0971 T003: routes receipt via ReceiptStore fresh route create writes .zfa/receipts/routes-Product.json
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 1776a796466961a1a0be2a8d09b48e56304bc4a063df483058e65f523c458aed
- hash: f7c5011ec835d0e7690400de4c3c0f8b5f719e516615c9bdb64b2a16c01f07aa

## Cycle: 0971-route-U3 (red)

- behavior: 0971-route-U3
- kind: red
- classification: compileError
- criterion: Order 4
- test: test/plugins/route/spec_971_t004_route_verify_test.dart
- command: `dart test test/plugins/route/spec_971_t004_route_verify_test.dart`
- exit: 1
- at: 2026-09-04T20:44:40.043382Z
- output:
```
test/plugins/route/spec_971_t004_route_verify_test.dart: Error: No named
parameter with the name 'testRunner'.
            RouteVerifyCommand(projectRoot: projectRoot, testRunner: runner),
lib/src/commands/route_verify_command.dart:21:3: Context: Found this
candidate, but the arguments don't match.
    RouteVerifyCommand({String? projectRoot})
00:00 +0 -1: Some tests failed. (loading failure)
```

- schema: 1
- prev-hash: genesis
- hash: d48929ea5887c62483246583201282c90ee0f9edce738ede51dccce8d8449167

## Cycle: 0971-route-U3 (green)

- behavior: 0971-route-U3
- kind: green
- criterion: Order 4
- test: test/plugins/route/spec_971_t004_route_verify_test.dart
- command: `dart test test/plugins/route/spec_971_t004_route_verify_test.dart`
- exit: 0
- at: 2026-09-04T20:44:52.499668Z
- output:
```
00:00 +0: loading test/plugins/route/spec_971_t004_route_verify_test.dart
00:00 +0: spec 0971 T004: zfa route verify <Entity> healthy table + passing test run exits 0 and writes the verdict receipt
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: d48929ea5887c62483246583201282c90ee0f9edce738ede51dccce8d8449167
- hash: b6e4ef128621c1093f0496163762f768f475d4a87004319b0340d0b56b15eb33

## Cycle: 0971-route-U4 (green)

- behavior: 0971-route-U4
- kind: green
- criterion: Order 5
- test: test/plugins/route/spec_971_t005_fix_lines_test.dart
- command: `dart test test/plugins/route/spec_971_t005_fix_lines_test.dart`
- exit: 0
- at: 2026-09-04T20:44:55.578847Z
- output:
```
(pin suite — arrived green; order 5 implementation landed with the T002/T004 cycles that share the command)
00:00 +0: loading test/plugins/route/spec_971_t005_fix_lines_test.dart
00:00 +0: spec 0971 T005: fix lines + structured skip verdicts route create with no entity: error + fix line + exit 64
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: genesis
- hash: 9d7b6b6ada2e9753004313a6a31db9c64875294e8d2ec8b52b6603c939315c22

## Cycle: 0971-route-A2 (refactor)

- behavior: 0971-route-A2
- kind: refactor
- criterion: Order 6 (verify)
- test: test/plugins/route/ (fast tier) + dart analyze + dart format
- command: `dart analyze && tools/run_tests_chunked.sh && dart format .`
- exit: 0
- at: 2026-09-04T20:44:55.581148Z
- output:
```
dart analyze: 0 new issues (31 pre-existing errors confined to
examples/todo_tdd, which requires Flutter codegen unavailable in this
environment; 0 errors/warnings in lib/ or test/).
Chunked fast suite: 74/74 chunks PASS (route chunk re-run 3x flake-free
after the -C CWD-race was removed from the new tests).
dart format .: 1987 files, 0 changed.
```

- schema: 1
- prev-hash: genesis
- hash: a2b6c7a3c1bf9cc9b5da5e36a8d55f6ecf845e623a281fc97a636be5432667b4

## Cycle: 0971-route-U13 (red)

- behavior: 0971-route-U13
- kind: red
- classification: assertionFailure
- criterion: Order 4 (audit remediation F1)
- test: test/plugins/route/spec_971_f1_reverse_drift_test.dart
- command: `dart test test/plugins/route/spec_971_f1_reverse_drift_test.dart`
- exit: 1
- at: 2026-09-04T20:49:07.022485Z
- output:
```
00:00 +0 -1: a route module added after the receipt (stale receipt) fails verification with a fix line [E]
  Expected: <1>
    Actual: <0>
  a stale receipt must not verify as healthy
00:00 +0 -1: Some tests failed.
```

- schema: 1
- prev-hash: genesis
- hash: 6eb4fa31a3c173f111b04ee59db65ce89aaeddbf61c77e460bbcd5f8db782e74

## Cycle: 0971-route-U13 (green)

- behavior: 0971-route-U13
- kind: green
- criterion: Order 4 (audit remediation F1)
- test: test/plugins/route/spec_971_f1_reverse_drift_test.dart
- command: `dart test test/plugins/route/spec_971_f1_reverse_drift_test.dart`
- exit: 0
- at: 2026-09-04T20:49:09.293534Z
- output:
```
00:00 +0: loading test/plugins/route/spec_971_f1_reverse_drift_test.dart
00:00 +0: a route module added after the receipt (stale receipt) fails verification with a fix line
```
- generation:
  (none)
- suite: baseline=0 guard=0 new=(none)

- schema: 1
- prev-hash: 6eb4fa31a3c173f111b04ee59db65ce89aaeddbf61c77e460bbcd5f8db782e74
- hash: de7fa48142310c3fb0652b118c26b7e52fb5cbbaf33579d4ef42a84338f3254e

