# TDD Verification — feature `1116-slice-verify-merge-gate`

Written from the ACTUAL runs performed on this branch (every command
below was executed on 2026-09-06; outputs are quoted from the
transcripts, not asserted). Toolchain: Dart 3.13.3 (stable) on
linux_x64 (`dart --version`). Flutter is NOT installed in this
environment — `flutter pub get` is unavailable, so every tier that
spawns it (the merge/e2e suites' host-suite runner) is out of scope
here; the failures those suites report on this machine are
pre-existing and byte-identical on the pristine tree (see "No
regressions" below).

## Gate

- gate: `passed`
- analyze: `dart analyze` over exactly the changed/new Dart files
  (`lib/src/plugins/slice/receipts/`, `slice_command.dart`,
  `slice_check_capability.dart`, `feature_slice_composer.dart`,
  `test/plugins/slice/slice_receipt_test.dart`) → **No issues found!**
- new acceptance suite: `dart test --preset=all
  test/plugins/slice/slice_receipt_test.dart` → **10/10 passed**
  ("All tests passed!"), after the RED run recorded below.
- slice-folder regression: `dart test --preset=all test/plugins/slice/`
  → **227 passed, 9 failed**; the 9 failures are pre-existing
  environmental (all spawn `flutter pub get` / the Flutter host suite).
- external touchpoints: `dart test --preset=all
  test/commands/slice_merge_exit_code_test.dart
  test/commands/manifest_flag_conformance_test.dart` → **13/13
  passed** ("All tests passed!").

## Red → green (TDD cycle)

1. **RED** — wrote `test/plugins/slice/slice_receipt_test.dart` first.
   `dart test --preset=all test/plugins/slice/slice_receipt_test.dart`
   → **0 passed, 10 failed**:
   - `PathNotFoundException: Cannot open file ... slice.receipt.json`
     (no skeleton from compose, no aggregation),
   - `Unknown slice subcommand: id` (R1 group).
   Root cause confirmed: no slice receipt schema, no aggregator, no
   `slice id`, no merge gate.

2. **GREEN** — implemented
   `lib/src/plugins/slice/receipts/{slice_receipt.dart,slice_receipt_aggregator.dart}`,
   the `id` subcommand + verify dispatch + merge gate in
   `slice_command.dart`, the compose skeleton in
   `feature_slice_composer.dart`, and the receipt-artifact exemption in
   `slice_check_capability.dart`. Same command → **10/10 passed**.

3. **refactor** — folded the per-section detail lines into the printed
   status (the red engine section must NAME the violator: entity +
   mock_class) and made the journal section map lint-clean. Re-ran:
   10/10, `No issues found!`.

## Real CLI proof (the actual binary, not in-process)

Probe project with the login contract (User/Session entities,
/login + /login/forgot routes, LoginRepository boundary), driven via
`dart run bin/zfa.dart slice ...` (transcripts quoted):

- `zfa slice id login` → prints `login`, exit 0.
- `zfa slice compose login` → "Slice written to .zfa/slices/login …";
  the written `slice.receipt.json` skeleton carries every section
  `"status": "pending"` and `"verdict": "pending"`.
- `zfa slice verify login` BEFORE the lanes ran → exit 1:
  `slice login: red — engine ❌ — skin ❌ — cert ❌ — xray ✅ — journal ❌`
  with per-section re-run commands (`zfa make engine login && zfa
  engine check login`, `zfa tdd run-skin login`,
  `zfa mock certify User`, `zfa tdd run login`) — the gate refuses a
  slice whose sub-receipts were never produced.
- After writing the five sub-receipts in the producers' exact schemas
  (`engine.receipt.v2`; `mock-cert.User.json`/`mock-cert.Session.json`
  schema 1 spec 1001; `skin.v1` with contract_rows_audited 6 and 3
  platform slot fills; journal with 2 green entries):
  `zfa slice verify login` → **exit 0**,
  `slice login: green — engine ✅ — skin ✅ — cert ✅ — xray ✅ — journal ✅`,
  and the aggregated receipt on disk:

  ```json
  {
    "schema": "slice.receipt.v1",
    "feature_id": "login",
    "verdict": "green",
    "engine":  {"status": "green", "n_methods": 2, "n_mocks_certified": 2},
    "skin":    {"status": "green", "n_routes": 2, "n_contract_rows": 6, "n_platforms_audited": 3},
    "cert":    {"status": "green", "uncertified_entities": [], "differential_passed": true, "n_certs": 2},
    "xray":    {"status": "green", "layers": {"engine": 8, "skin": 4, "shared": 0}, "violations": []},
    "journal": {"status": "green", "cycles": 2, "violations": 0, "final_state": "green"}
  }
  ```

- Mutation: one engine method flipped to `"mock_certified": false` →
  `zfa slice verify login` → **exit 1**:
  `slice login: red — engine ❌ — skin ✅ — cert ✅ — xray ✅ — journal ✅`,
  naming the violator —
  `engine: method mock_class "MockLogout" is uncertified (entity User) — the CERT-GATE signal` —
  and printing the exact re-run command: `re-run engine: zfa engine check User`.
- Merge gate on that red slice: `zfa slice merge login` → **exit 1**,
  `Merge refused: the slice receipt for "login" is red — the merge gate
  (spec 1116) requires a green slice.receipt.json. … --> fix: run
  \`zfa slice verify login\` …`.
- After the named re-run (method re-certified): verify exit 0, then
  `zfa slice merge login` → exit 0,
  `merge gate: slice "login" receipt is green — merge may proceed (spec 1116).`
- `zfa slice id login` before/after `zfa slice compose login --force`
  → `login` / `login` — stable across re-compositions.

## Success criteria (issue #1116) — proved vs not

- ✅ `zfa slice compose <id> … && zfa slice verify <id>` exits 0 with
  `slice.receipt.json` showing all sub-receipts green — PROVED (real
  CLI, steps above; the sub-receipts were written in the producers'
  exact schemas rather than produced by a full Flutter-dependent
  `zfa make engine` + `zfa tdd run-skin` chain — see the honest
  boundary in spec.md).
- ✅ A test mutates one sub-receipt to red; `slice verify` exits 1,
  names the violator, prints the exact re-run command — PROVED (test
  R4 AND the real CLI run).
- ✅ `zfa slice verify` is the merge gate for the slice worktree —
  PROVED (red refused with exit 1 + fix path; green proceeds).
- ✅ `zfa slice id <id>` prints the FeatureContract id, stable across
  re-compositions — PROVED.
- ✅ compose writes the empty `slice.receipt.json` skeleton — PROVED.

## No regressions

`dart test --preset=all test/plugins/slice/` on THIS branch vs the
pristine tree (git stash): the failing-test lists are byte-identical
(9 pre-existing environmental failures: A4b cut barrel, A5–A8 merge,
T073/T074 polish, T075 e2e, the #1113 worktree journal equivalence —
each spawns `flutter pub get` or the Flutter host-suite runner;
`ProcessException: No such file or directory, Command: flutter pub
get`). Pass counts: pristine +217, this branch +227 (= +10, exactly
the new suite); previously-passing tests all still pass.
