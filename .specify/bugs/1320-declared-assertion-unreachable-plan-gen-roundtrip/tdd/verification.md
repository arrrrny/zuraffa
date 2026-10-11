# TDD Verification — bug #1320 (declared-assertion path unreachable: plan never writes the contract row into the unit traces cell; hand-delta destroyed by re-plan; gen refuses to re-generate)

Verification record for the bug-fix PR
`fix/1320-declared-assertion-unreachable-plan-gen-roundtrip`. Every number
below is from a command actually executed in this session (Dart SDK
3.13.3 stable, Linux x64, repo HEAD `cc0a60ab`). Nothing is projected,
copied, or back-dated from another run. `zfa tdd verify` mutation gates do
NOT apply to this record (the fix surface is the CLI plan/gen/driver
plumbing, not a feature test list) — stated under "Not proved".

## Fix scope (hard-constraint compliant)

Changed files — and ONLY these:

- `lib/src/plugins/tdd/commands/plan_command.dart` — plan-time method
  resolution (`_qualifiedTraces`) feeding BOTH writers (the legacy
  test-list writer and the lane writer `_derivedLaneRows` via the shared
  `contractTraces` map + `_tracesCell`): single-method rows resolve
  directly, multi-method rows resolve by FR-prose verb match, ambiguous
  traces refuse with exit 2 + the exact `--> fix:`. No engine change, no
  verify-gate change, no contract-scanner change, no Lane Contract
  format change.
- `lib/src/plugins/tdd/commands/gen_command.dart` —
  `_regenerateStaleStub` now reports its cause; when the traces cell
  gained a contract token since the owned artifact was generated
  (declared shape resolves + owned test still vacuous-green), gen
  rewrites the pair and reports `verdict=regenerated` (per-behavior,
  batch counts, and JSON envelope) instead of `reused`.
- `lib/src/plugins/tdd/services/vacuous_guard.dart` —
  `vacuousGuardFallbackRemedy` names the designed hand-delta seam
  (hand-edit the lane plan traces cell to `FR-00N, Row.method`, re-run
  gen). One shared constant: gen's warning, the writer, and the run
  driver's stop message cannot drift.

Not changed: core engine, verify gate, contract scanner, Lane Contract
format, run_driver_core.dart (the stop message picks up the seam naming
through the shared constant).

## Red (before the fix) — ACTUAL

New suite:
`test/plugins/tdd/commands/bug_1320_declared_assertion_reachable_test.dart`

```
dart test test/plugins/tdd/commands/bug_1320_declared_assertion_reachable_test.dart
→ 00:01 +0 -8: Some tests failed.
```

All 8 behaviors RED, mapping 1:1 to the four interlocking gaps:

- U1/U2/U3 (plan method-qualified cell, legacy + lane writer + verb
  match): cell carried the row-only token (`FR-001, RouteContentType`),
  the method never surfaced.
- U4 (ambiguous multi-method trace): plan exited 0 and wrote artifacts
  instead of refusing — the silent `all.first` mis-route.
- U5 (round-trip): re-plan reverted the method-qualified cell
  (the hand-delta destroyed).
- U6/U7 (gen re-generation verdict): gen regenerated the pair (the #683
  mechanics) but reported `verdict=reused` with the misleading
  `binary updated, stub regenerated` note:

```
'ownership: reused/reused\n'
'gen: behavior=U1 verdict=reused kind=unit\n'
Which: does not contain 'verdict=regenerated'
```

- U8 (seam in the remedy): the shared remedy carried no hand-delta seam
  naming.

## Green (after the fix) — ACTUAL

```
dart test test/plugins/tdd/commands/bug_1320_declared_assertion_reachable_test.dart
→ 00:08 +8: All tests passed!
```

- U1: unit cell = `FR-001, RouteContentType.contentType` (legacy
  test-list writer).
- U2: same cell in the lane plan `04-ENGINE.md` (lane writer).
- U3: multi-method row resolves by FR-prose verb match.
- U4: ambiguous trace refuses — exit 2, `--> fix:` names the exact
  `traces: RouteContentType.<method>` remedy, NO artifacts written.
- U5: the method-qualified cell round-trips a re-plan byte-for-byte.
- U6: after the traces cell gains a contract token, the stale
  guard-only pair is regenerated and gen prints
  `verdict=regenerated` + `note: traces cell gained a contract token
  since generation — pair regenerated (issue #1320)`; the test gains
  `expect(result, isA<String>())`, the vacuous guard is gone.
- U7: end-to-end trace→plan→gen→regen→verify-red→make certifies GREEN
  with zero `vacuous-green` (the capstone path is reachable through zfa
  commands alone, no hand-edit).
- U8: the shared remedy names `Row.method`, `04-ENGINE.md`, and the
  `hand-delta seam` explicitly.

## Regression scope (only suites touching the changed files) — ACTUAL

Fast tier, chunked per the repo's dart_test.yaml guidance for
small-disk agents (one-shot folder runs overflow the kernel cache and
fail to LOAD — that failure mode was observed and is environmental, not
a regression; each chunk below was run after clearing
`.dart_tool/test/`):

```
dart test test/plugins/tdd/commands
→ 01:31 +399: All tests passed!

dart test test/plugins/tdd/services
→ 01:33 +773: All tests passed!

dart test test/plugins/tdd/*.dart        (top-level suites, fast tier)
→ 00:41 +449: All tests passed!

dart test test/plugins/tdd/models
→ 00:02 +81: All tests passed!
```

Consolidated focused re-run (fix suites + every suite that asserts the
changed vocabulary/verdict surfaces):

```
dart test \
  test/plugins/tdd/commands/bug_1320_declared_assertion_reachable_test.dart \
  test/plugins/tdd/issue_1308_vacuous_guard_remedy_test.dart \
  test/plugins/tdd/issue_1308_vacuous_guard_remedy_driver_test.dart \
  test/plugins/tdd/commands/gen_command_test.dart \
  test/plugins/tdd/commands/plan_traces_cell_1310_test.dart \
  test/plugins/tdd/commands/plan_unbound_traces_1319_test.dart \
  test/plugins/tdd/services/spec_parser_traces_1319_test.dart
→ 00:18 +39: All tests passed!
```

```
dart test \
  test/plugins/tdd/commands/plan_skin_contract_1004_test.dart \
  test/plugins/tdd/make_command_declared_071_test.dart \
  test/plugins/tdd/bug_846_coverage_gate_test.dart \
  test/plugins/tdd/bug_1140_finder_kind_plan_column_test.dart \
  test/plugins/tdd/bug_993_plan_entity_export_clash_test.dart \
  test/plugins/tdd/bug_1272_gen_project_scoped_test_list_test.dart
→ 00:03 +37: All tests passed!
```

The `issue_1308` driver suite was run via `--preset=all` (slow tag) —
4/4 passed, including U-1308-4's transcript-forward scan against the
extended remedy string.

The #683 binary-drift tests (`gen_command_test.dart`) still pass:
binary drift keeps the `binary updated, stub regenerated` note; only
contract drift reports `regenerated`.

## Analyzer — ACTUAL

```
dart analyze lib/src/plugins/tdd/commands/plan_command.dart \
  lib/src/plugins/tdd/commands/gen_command.dart \
  lib/src/plugins/tdd/services/vacuous_guard.dart
→ No issues found!
```

(The pre-existing baseline of repo-wide analyzer infos at HEAD is
unchanged; none of the 104 infos touch the changed files.)

## Format gate — ACTUAL

```
dart format --output=none --set-exit-if-changed <the 6 changed files>
→ Formatted 6 files (0 changed) in 0.07 seconds.
→ FORMAT CLEAN
```

`dart format .` at repo level surfaced PRE-EXISTING drift in four files
outside this fix's scope (two byte-exact corpus regression fixtures,
`specs/1256-.../tdd/red_repro.dart`,
`test/plugins/tdd/bug_1333_refactor_reproof_retry_test.dart`). Those
were reverted to HEAD byte-for-byte (formatting them risks breaking
byte-compare corpus fixtures and is not this PR's business); the six
changed files are format-clean.

## Proved vs not proved

PROVED (real runs above):

1. Plan (both writers) writes the method-qualified cell when an FR's
   `traces:` binds to a contract row (single-method direct; multi-method
   verb match).
2. The prior-row read round-trips method-qualified cells (the #1320
   hand-delta survives re-plan; the obsolete uppercase-only regex class
   cannot revert them).
3. An ambiguous declared trace refuses at plan with the exact `--> fix:`
   and zero artifacts (errors-are-an-API).
4. Gen re-generates the stale guard-only pair once the traces cell
   gained a contract token and reports `verdict=regenerated` — the
   re-gen remedy exists as command output, not a dead end.
5. The trace→gen→regen→verify-red→make path certifies green end-to-end
   through zfa commands alone (U7).
6. The vacuous-green stop remedy names the hand-delta seam explicitly.
7. No regression in any suite touching the changed files (1,777 fast +
   4 slow assertions in scope, all green).

NOT PROVED (stated honestly):

- `zfa tdd verify` mutation gates were not run: the fix surface is CLI
  plumbing with no feature test list; the new suite is the verification
  surface (same disposition as the #1182 record).
- The full slow tiers (regression/integration/property/benchmark) were
  not run: the repo's dart_test.yaml explicitly forbids `--preset=all`
  whole-suite runs on small agents (temp-project pub get + build_runner
  fill several GB). The in-scope slow suite (#1308 driver) WAS run.
- Flutter consumers were not exercised (no Flutter SDK on this agent);
  the changed code is pure Dart and `dart analyze` is clean.
