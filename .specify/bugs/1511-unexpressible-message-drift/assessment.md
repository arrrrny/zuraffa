# Bug Assessment: BUG 1511 — make_command_test "bug 657" assertion drift on the unexpressible message

- **Slug**: 1511-unexpressible-message-drift
- **Created**: 2026-09-12
- **Source**: BUG 1511 (pre-existing red on `make_command_test.dart`, test "bug 657")
- **Verdict**: valid — reproduced locally on `master` (03cdf45b) before any fix
- **Severity**: low (test-only drift; production logic and the outcome/exit contract are correct)

## Report (verbatim or summarized)

The "bug 657" test in `test/plugins/tdd/make_command_test.dart` is pre-existing red. It
expects the stderr/stdout of an unexpressible `zfa tdd make` to contain
`no generator for 'provision'`, but the actual message emitted by the make command is
now the full behavior-phrased refusal:

```
zfa tdd make: cannot plan a generation for behavior "B-042". behavior "B-042" requires
an implementation the zuraffa generation pipeline cannot express: no generator surface
maps the behavior description "provision bespoke DSL syntax with no generator surface"
to a `zfa entity create` / `zfa make` / `zfa build` invocation. File a zuraffa gap per
the STOP-ON-ROADBLOCK policy.
```

The assertion was never updated when the wording drifted, so the test pins a message
that no longer exists.

## Symptom

`dart test --preset=all test/plugins/tdd/make_command_test.dart -n "bug 657"` reports
one failure at `make_command_test.dart:955`:

```
Expected: contains 'no generator for \'provision\''
  Which: does not contain 'no generator for \'provision\''
```

The sibling "bug 657" green-path test (render-type behavior plans `tdd func`) passes,
so the drift is isolated to the unexpressible-refusal assertions.

## Reproduction

1. Clone `arrrrny/zuraffa` at `master` (`03cdf45b`), `dart pub get`.
2. `dart test --preset=all test/plugins/tdd/make_command_test.dart -n "bug 657"`.
3. Observed: `+0 -1` — the unexpressible-path test fails on the `contains` assertion
   above. Exit code 1.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/generation_planner.dart` — `_unexpressibleReason()`
  (the message source; rewritten at some point to phrase the refusal in behavior terms
  per SC-005: names the behavior, quotes the full description, cites the
  STOP-ON-ROADBLOCK policy).
- `lib/src/plugins/tdd/commands/make_command.dart` — the unexpressible stop
  (`zfa tdd make: cannot plan a generation for behavior "<id>". <reason>` +
  `make: behavior=<id> outcome=unexpressible feature=<feature>` summary line).
- `test/plugins/tdd/make_command_test.dart:938` — the drifted test.

## Root Cause Hypothesis

`make_command.dart`'s unexpressible-path wording was improved (behavior-phrased
refusal with the full description and the STOP-ON-ROADBLOCK policy reference) and the
"bug 657" test assertion was not updated in the same change. The old contract
fragments — `no generator for '<verb>'`, `implement manually at <stub_path>`,
`then re-run` — no longer exist anywhere in `lib/` (`rg` confirms zero hits), so the
test now asserts a stale message.

This is message-drift only: the outcome/exit contract
(`make: behavior=B-042 outcome=unexpressible feature=…`, non-zero exit, no pipeline
subprocess attempted, test/lib files untouched) is intact in the captured output.

## Proposed Remediation

Test-only change (no production code, no state-machine change): rewrite the test name
and assertions in `make_command_test.dart` to pin the CURRENT message contract —
the refusal names the behavior, quotes the exact description
(`"provision bespoke DSL syntax with no generator surface"`), and cites the
STOP-ON-ROADBLOCK policy — while keeping the unchanged outcome/exit assertions.

## Risks & Considerations

- Scope is deliberately restricted to `test/plugins/tdd/make_command_test.dart`;
  `lib/` is untouched, so no behavior can change.
- The test name must keep the `bug 657:` prefix so the `-n "bug 657"` filter (used by
  the verification protocol) keeps matching both bug-657 tests.
- Full fast suite must be re-run chunked to prove no other test pinned the old
  wording (`rg "no generator for" test/` shows this is the only occurrence).
