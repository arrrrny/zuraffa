# TDD Test List — Spec 1411

Red pre-fix (executed 2026-09-11, `dart test --preset=all
test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart`):
**+1 −9** — B1..B7, D1, D2 RED (the transition/offer/hand-off do not
exist: B1 exits non-zero with the plain refusal; D1/D2 stop with the
generic `resume: fix the failing step` hint — the issue's dead end);
D3 guard green from the start (the generic stop already exists — the
compatibility pin).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | make --born-green, full gate (passing test, marker absent, header present, no red) → exit 0, outcome=born-green, green evidence | FR-1 / AS-1 | test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart |
| B2 | make (no flag), attested shape → not-certified-red refusal naming `--born-green` | FR-2 / SC-002 | test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart |
| B3 | make --born-green, marker present → vacuous-green safe-failure | FR-3 | test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart |
| B4 | make --born-green, header absent → not-certified-red naming the exact header line | FR-3 | test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart |
| B5 | make --born-green, failing test → not-certified-red naming verify-red | FR-3 / SC-001 | test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart |
| B6 | certified red + flag → the #694 skip transition (flag inert) | FR-5 / AS-3 | test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart |
| B7 | make --born-green, passing test against a PLACEHOLDER subject (vacuous scaffold) → vacuous-green refusal (the #1036 class) | FR-3 / SC-001 | test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart |
| D1 | run: attested catch-22 → hand-off naming --born-green + stopped_at=<id>:hand + journal violation | FR-4 / AS-2 | test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart |
| D2 | run: un-attested → the exact header line named | FR-4 | test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart |
| D3 | run: red-first-shaped refusal → the generic stop stands | FR-5 / AS-3 | test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart |

## Red protocol

```
dart test test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart
```

Each behavior traces one acceptance criterion: AC1 → B1, AC2 → D1,
AC3 → B6 + D3.
