**Template Version**: `zuraffa-1.0`

# Tasks: 1542-refactor-evidence-red-for-contract-lane

## 1. Specification & tests first (TDD — every behavior lands red first)

- [x] 1.1 Write `specs/1542-refactor-evidence-red-for-contract-lane/spec.md`
      with the measurable success criteria (SC-1..SC-5) and the hard
      constraints (contract lane / blocked verdict / state machine
      untouched).
- [x] 1.2 Write `plan.md` (technical context + design decisions D1..D4)
      and derive `tdd/test-list.md` (the TDD extension's behavior list).
- [x] 1.3 **[RED]** Driver suite
      `test/plugins/tdd/bug_1542_born_green_contract_refactor_test.dart`:
      U-1542-1 (contract-lane green-only completes), U-1542-2 (born-green
      journal marker completes), U-1542-3 (marker-less twin misfires
      byte-identically), U-1542-4 (full blocked+born-green flow re-enters
      at refactor, never at make, and completes). Capture the red
      transcripts into `tdd/cycle-log.md` BEFORE any production change.
- [x] 1.4 **[RED]** Make-level suite
      `test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart`
      extension: M-1542-1 (`--born-green` flips a seeded `blocked` state to
      `done` on disk + prints the advancement), M-1542-2 (no state file →
      still exit 0, none written), M-1542-3 (`pending` state untouched).
      Capture red evidence into `tdd/cycle-log.md`.

## 2. Production change — the two seams only

- [x] 2.1 **[GREEN for U-1542-2/3]** `born_green.dart`: add the shared
      `bornGreenEvidenceMarker` constant (FR-005/D4).
- [x] 2.2 **[GREEN for U-1542-2/3]** `cycle_evidence.dart`: parse the
      optional `- evidence:` line into `ParsedCycleEntry.evidence`; add
      `CycleEvidence.bornGreenCertified` (FR-002/D1).
- [x] 2.3 **[GREEN for U-1542-1/2/3/4]** `run_driver_core.dart`:
      `_evidenceMisfire` gains `BehaviorKind? kind`; the `refactor` case
      accepts green-only for the contract lane and for born-green-certified
      behaviors; message byte-identical for the non-exempt classes
      (FR-001/FR-003).
- [x] 2.4 **[GREEN for M-1542-1/2/3]** `make_command.dart`: the born-green
      transition interpolates the shared marker constant (byte-identical
      append) and advances `run-state.json` `blocked → done` through
      `RunStateStore` with the advancement line printed (FR-004/FR-006/D3).

## 3. Regression & verification

- [x] 3.1 The pinned bug #682 green-only honesty suite
      (`run_command_test.dart`) stays green UNCHANGED (FR-003/SC-2).
- [x] 3.2 The #1411 suites (make B1..B7, driver D1..D3) stay green
      unchanged (backward compat).
- [x] 3.3 `dart analyze` on the changed files: zero new findings (SC-5).
- [x] 3.4 Fast-tier TDD suite green (`dart test test/plugins/tdd/`).
- [x] 3.5 Write `tdd/verification.md` (test-first evidence, acceptance
      coverage, suite results) and commit the spec-kit artifacts.
