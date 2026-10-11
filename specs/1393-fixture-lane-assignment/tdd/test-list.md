# TDD Test List — Spec 1393

Red pre-fix: `dart test test/plugins/tdd/commands/bug_1393_fixture_lane_pin_test.dart`
→ `+1 -3` (B1/B2/B4 red against the shipped fixture; B3 green — the Skin
Contract yaml was already repaired on master per spec 1377). Reproduction of
the issue's engine stop on the shipped fixture: A1/A2 make `unexpressible`
→ deferred (phase 2); U1 make `vacuous-green` → `stopped_at=U1:make`.

## Behaviors

| # | Behavior | Trace | Test file |
|---|----------|-------|-----------|
| B1 | U1 (FR-001, adaptive view presentation) is declared SKIN, not CORE | FR-001 / AS-1 | test/plugins/tdd/commands/bug_1393_fixture_lane_pin_test.dart |
| B2 | The CORE lane carries an engine-expressible unit: FR-002 traces `LoginValidation.isSubmittable` to a declared scalar-return callable row | FR-002 / AS-2 | test/plugins/tdd/commands/bug_1393_fixture_lane_pin_test.dart |
| B3 | The `## Skin Contract` yaml parses with the strict production parser (`parseAdaptiveSkinContract`) | FR-004 / AS-5 | test/plugins/tdd/commands/bug_1393_fixture_lane_pin_test.dart |
| B4 | The committed `tdd/split-receipt.json` carries the re-split classification (A1/A2/U2 CORE; W1/U1/A3–A7 SKIN) | FR-003 / AS-1 | test/plugins/tdd/commands/bug_1393_fixture_lane_pin_test.dart |
| B5 | The engine cycle completes unattended: gen → verify-red (certified) → make (U2 func scaffold; A1/A2 spec 052 composition off the green U2 anchor) → refactor | FR-002 / AS-3 | the real CLI cycle (`zfa tdd run 004-login-ui`), receipt: example/specs/004-login-ui/tdd/04-engine-receipt.json |

## Red protocol

```
dart test test/plugins/tdd/commands/bug_1393_fixture_lane_pin_test.dart
zfa tdd run 004-login-ui --project example   # reproduce the vacuous-green stop
```
