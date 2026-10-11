# Bug Issue: BUG 1511 — unexpressible message drift in make_command_test (bug 657)

- **Slug**: 1511-unexpressible-message-drift
- **Created**: 2026-09-12
- **Kind**: test-assertion drift (pre-existing red)
- **Affects**: `test/plugins/tdd/make_command_test.dart` — test `bug 657: an
  unexpressible make …`
- **Status**: fixed on `fix/1511-unexpressible-message-drift`

## Summary

Pre-existing red on `make_command_test.dart`. The "bug 657" test expects the
unexpressible `zfa tdd make` output to contain `no generator for 'provision'`, but the
message drifted to the behavior-phrased refusal:

> `no generator surface maps the behavior description "provision bespoke DSL syntax
> with no generator surface" to a `zfa entity create` / `zfa make` / `zfa build`
> invocation. File a zuraffa gap per the STOP-ON-ROADBLOCK policy.`

The test assertion was not updated when the wording improved, so the test pins a
string that no longer exists in the codebase.

## Expected behavior

The "bug 657" unexpressible-path test passes and pins the CURRENT message contract:
the refusal names the behavior, quotes the full behavior description, and cites the
STOP-ON-ROADBLOCK policy. The outcome/exit contract assertions
(`make: behavior=B-042 outcome=unexpressible feature=…`, non-zero exit) remain
unchanged.

## Actual behavior (before fix)

```
dart test --preset=all test/plugins/tdd/make_command_test.dart -n "bug 657"
→ 00:08 +0 -1: … bug 657: an unexpressible make names the verb and the stub path … [E]
  Expected: contains 'no generator for \'provision\''
    Which: does not contain 'no generator for \'provision\''
Some tests failed.
```

## Root cause

`make_command.dart`'s unexpressible-path wording drifted (now produced by
`GenerationPlanner._unexpressibleReason()` in
`lib/src/plugins/tdd/services/generation_planner.dart`); the test assertion was not
updated. The stale fragments (`no generator for '<verb>'`, `implement manually at`,
`then re-run`) no longer appear anywhere in `lib/`.

## Constraints honored

- Fix ONLY the test in `make_command_test.dart` — no change to make command logic or
  the state machine.
- `dart analyze` on the changed file: no issues, no new warnings.
- Pre-existing failure on `master` (`03cdf45b`) — not introduced by any current PR.

## Fix

Rewrite the test name (keeping the `bug 657:` filter prefix) and replace the stale
`contains` assertions with the current-contract assertions:

- `contains('no generator surface maps the behavior')`
- `contains('description "provision bespoke DSL syntax with no generator surface"')`
- `contains('STOP-ON-ROADBLOCK policy')`
- outcome/exit summary line assertions unchanged.
