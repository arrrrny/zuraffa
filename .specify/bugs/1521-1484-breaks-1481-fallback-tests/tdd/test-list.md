# Test List: 1521-1484-breaks-1481-fallback-tests (bug #1521)

Derived from `assessment.md` ("Tests to add or update"). The suite is
`test/plugins/tdd/commands/plan_command_bug_1481_test.dart` (8 tests);
this bug's red-green loop touches ONLY the three tests in the group
`#1481: the two fallback classes are distinguishable` that feature
1484 stranded. Test IDs here map 1:1 to the three failing tests from
the issue.

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| T-U1 | an unbound FR (no surviving `traces:` binding) routes to a manual declaration: `WARNING: FR-001 derives no unit behaviour` rendered, destination named (`recorded as a manual declaration in tdd/traceability.md`), both remedies named (`add a `traces:` line naming a declared contract row`, `add `**Type**: manual` under the FR`), no unit route line (`isNot(contains('route: U1'))`), no fatal fallback class (`isNot(contains('[fallback: no declared trace'))`) — while the scenario heals to `[declared: type marker` in the same invocation and spec.md carries `**Type**: acceptance` | feature-1484 manual routing (plan_command.dart L263–276) | DONE |
| T-U2 | every unbound FR gets its own manual-declaration warning (FR-001 AND FR-002 both announced) and no dead-end tally is emitted (`isNot(contains('will dead-end at make'))`) — manual-routed FRs never reach make as automated unit behaviours | feature-1484 manual routing | DONE |
| T-U3 | the per-FR warning scales to PLURAL unbound FRs: a 3-FR fixture yields three warnings (FR-001, FR-002, FR-003) and no dead-end tally | feature-1484 manual routing | DONE |

## Preserved invariants (not touched, must stay green)

| id | behavior | state |
| -- | -------- | ----- |
| INV-1..INV-5 | the five healable-spec tests: post-migration verdict in one invocation, artifact/stdout agreement, one-time migration (no repeat announcement), mutation announcement, `--no-emit-markers` repairable class | PASS (unchanged) |

## Test artifacts

- T-U1..T-U3 → `test/plugins/tdd/commands/plan_command_bug_1481_test.dart`
  (fast tier, hermetic `Directory.systemTemp` fixtures driven through
  `CliRunner.runCapturing`).

## Red-green protocol

- RED: at branch HEAD `58ad4eed` with the test file pristine — 3 of 8
  tests fail (`+5 -3: Some tests failed.`), exactly T-U1..T-U3's
  pre-1484 assertions. Pinned in `tdd/red-evidence.md`.
- GREEN: expectations updated to the feature-1484 contract — 8 of 8
  pass (`00:00 +8: All tests passed!`).
