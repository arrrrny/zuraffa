# TDD Cycle Log — Spec 1400

## RED (recorded)

1. **Issue-filing red (2026-09-09 07:33Z, quoted in #1400)** — on the
   post-merge tree (f5fb5355, deps dropped):
   `zfa tdd verify --feature 004-login-ui --project example --runner flutter`
   → `mutation config error: Could not find package 'mutation_test'`,
   `gate: not_assessed`, `mutation_was_run: false`.
2. **Residual red at HEAD (2026-09-11, re-run on this branch)** — full
   lane stops at the preflight:
   `gate: preflight_red`, `mutation_was_run: false` — via
   `test/tdd/004-login-ui/u1_test.dart`
   (`UnimplementedError: subject_u1 not implemented`, #1377's deliberate
   honest-red stub; unrelated pre-existing failure, owned by the U1
   lane, source-code change forbidden here).
3. **Counter-evidence red (2026-09-11)** — plain `test: ^1.0.0`
   re-inserted into `example/pubspec.yaml`:
   `flutter pub get` → version solving failed
   (`flutter_test from sdk is incompatible with test`,
   #1189/#1370 conflict class; Flutter 3.47.3 / Dart 3.13.3). Reverted;
   resolution re-proven clean after revert.

The restoration half of red (1) was repaired on master before this
branch existed (#1369 restore, 20:14Z; #1370 supersession, 20:27Z — both
2026-09-09), so the red→green CODE cycle for the data fix is recorded
in specs/1369-* and specs/1370-*. This spec's cycle CERTIFIES that
repaired state with real runs.

## GREEN (2026-09-11)

- B1/B2: structural pin
  `dart test test/package_sdk/bug_1369_example_tdd_baseline_test.dart`
  → `+1: All tests passed!`
- Evidence-scope preflight (the committed evidence's exact registered
  scope; u1 excluded — did not exist in the evidence's scope):
  `flutter test test/presentation/pages/login/login_view_test.dart
  test/tdd/004-login-ui/a3_test.dart ... a7_test.dart`
  → `+8: All tests passed!`
- B3: scoped mutation audit on the restored tree — see
  [verification.md](./verification.md) for the run record and the
  bit-exact comparison against the committed evidence.
- SC-001: `flutter pub get` in `example/` → `Got dependencies!`
  (zero dependency_overrides).
