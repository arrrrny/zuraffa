# Tasks: 1537-dead-end-machinery-coverage

- **Spec ID**: 1537-dead-end-machinery-coverage
- **Created**: 2026-09-13

Dependency order: T001 (pinning tests, red evidence against the deletion
mutant) → T002 (machinery restored, green evidence) → T003 (non-behavioural
provenance-doc correction in plan_command.dart + test-file header truth
repair) → T004 (verify + artifacts).

## T001: Red — pinning tests against the deletion mutant
- Add the fixture + group to `test/plugins/tdd/commands/plan_command_bug_1481_test.dart`:
  - fixture `_criterionOnlyTraceSpec`: FR-001 with `[persistent]` tag and
    inline `traces: FR-001` (criterion-only binding), one acceptance scenario
  - P1 (SC-1): default flags → exit 0, fatal route line for U1 renders,
    tally line `1 behavior will dead-end at make` renders with U1
  - P2 (SC-2): the same spec minus the `[persistent]` tag with
    `--allow-unit-fallback` → exit 0, tally renders with U1
  - P3 (SC-3): SC-1 fixture under `--json` → envelope
    `details.dead_end_behaviors == 1`
- RED EVIDENCE: apply the deletion mutant to `plan_command.dart` (remove
  `if (!repairable) deadEnds.add(b.id);`, the fatal prefix ternary, both
  `_printDeadEndTally` calls, both `dead_end_behaviors` writes) → run the
  new group → all three tests FAIL → record `tdd/red-1537.log` → restore
  the file byte-identically (SC-4)
- Tests: `plan_command_bug_1481_test.dart`

## T002: Green — machinery live, pins hold
- Restore `plan_command.dart` to HEAD (machinery intact)
- Run the full file suite → every test green (new pins + the existing
  #1481 guards, SC-5) → record `tdd/green-1537.log`
- Tests: `plan_command_bug_1481_test.dart`

## T003: Non-behavioural — provenance documentation correction
- `lib/src/plugins/tdd/commands/plan_command.dart`, comments only:
  - the `_provenanceLines` dead-end doc block: post-1484 the surviving
    unit-kind `RoutingUndeclared` source is the criterion-only trace
    binding; name the seam and the two live routes
  - the `RoutingUndeclared` fallback comment: same correction, point at
    the pinning group
  - the `_printDeadEndTally` doc: the tally is reachable (persistence-
    marked exemption / `--allow-unit-fallback`), not "unrouted"
- `test/plugins/tdd/commands/plan_command_bug_1481_test.dart` header
  comment: amend the "out of reach for unbound FRs" claim to the SC-6
  wording (SC-6)
- No rendered string, exit code, or routing decision changes
- Tests: `plan_command_bug_1481_test.dart` (unchanged, still green)

## T004: Verify + artifacts
- `dart analyze` on changed files → no new warnings
- targeted re-runs of the #1481 file + neighboring suites
  (`plan_routing_provenance_test.dart`, `plan_marker_emission_1186_test.dart`)
- `dart format .` → `git diff --stat` reviewed
- Write `tdd/verification.md` (FRESH from the actual run): verdict, gate
  table, red/green evidence pointers, mutant result
- Commit, push, PR (`Closes #1537`)
