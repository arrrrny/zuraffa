**Template Version**: `zuraffa-1.0`

# Spec: 1542-refactor-evidence-red-for-contract-lane

## Summary

A contract-lane behavior wired through the born-green path (`// zfa:tdd: <id>:hand`
attestation + `zfa tdd make <id> --born-green`, issue #1411) earns its green
evidence honestly — but the run still dead-ends at the refactor step with
`refactor certified but evidence for "contract:A7" is incomplete in
cycle-log.md (red: false, green: true)`. The dead-end is STRUCTURAL, not a
bug in one lane: (1) contract-lane reds are BLOCKED-never-RED by design
(issue #1007), so a certified-red contract entry is unobtainable; (2) the
born-green hand transition (issue #1411) certifies green WITHOUT a prior red
by definition. Therefore `red: true` can never hold for a born-green contract
behavior and the run can never complete. Two independent dead-ends compound:
`make --born-green` certifies green but never advances `tdd/run-state.json`,
so a behavior parked at `blocked` stays `blocked` and the re-run re-enters at
verify-red → make, where make (spawned WITHOUT `--born-green`) refuses
`not-certified-red`. This feature defines red out of existence for the two
classes where red is unobtainable BY DESIGN, and makes the born-green
transition advance the run state it completes.

## Acceptance Scenarios

1. **Given** a contract-lane behavior whose cycle-log carries green evidence
   but no red evidence (BLOCKED-never-RED, issue #1007) **When** the run
   driver certifies the refactor step **Then** the refactor evidence check
   accepts `green: true` alone — the run completes with the behavior
   landing at `green`; the misfire message is not emitted. (`done` is
   unreachable for the green-only classes: the bug #682 reconcile rule
   demotes a `done` claim carrying green-only evidence back to `green`,
   which is what keeps the behavior re-provable — see SC-4.)
2. **Given** any behavior whose LAST green evidence entry certifies the
   born-green hand transition (the journal carries the #1411 transition
   marker the `--born-green` transition writes) **When** the run driver
   certifies the refactor step **Then** the evidence check accepts the
   green-only certification — red is defined out of existence for the
   born-green class regardless of lane.
3. **Given** a behavior whose state is `blocked` in `tdd/run-state.json`
   **When** `zfa tdd make <id> --born-green` certifies green **Then** the
   run state file advances the behavior `blocked → done` — the next run
   re-enters at the refactor step (via the evidence reconciliation) instead
   of re-stopping at make's `not-certified-red` refusal.
4. **Given** a born-green contract behavior that completed its hand step
   **When** the author runs the full flow (`zfa tdd run` → blocked stop →
   `zfa tdd make <id> --born-green` → `zfa tdd run`) **Then** the run
   completes without manual `run-state.json` surgery.
5. **Given** a NON-contract, NON-born-green behavior with green-only
   evidence (the bug #682 honesty class) **When** the run driver certifies
   the refactor step **Then** the evidence check still misfires with
   `(red: false, green: true)` — the strict red→green→refactor triple is
   unchanged for every class where red IS obtainable.

## Functional Requirements

- **FR-001**: The run driver's refactor evidence misfire check
  (`run_driver_core.dart` `_evidenceMisfire`, step `refactor`) MUST accept
  green-only evidence when the behavior is a CONTRACT-lane row
  (`BehaviorKind.contract`) — the lane whose verify-red verdict is BLOCKED,
  never a certified red (issue #1007). The green half stays mandatory: a
  contract behavior with NO green evidence still misfires.
- **FR-002**: The same check MUST accept green-only evidence when the
  behavior's LAST green cycle-log entry certifies the born-green hand
  transition — the entry's `- evidence:` field carries the shared journal
  marker the `--born-green` transition writes (`bornGreenEvidenceMarker`,
  issue #1411). The probe keys on the journal (cycle-log.md), not the run
  state, so the certification survives state-file resets.
- **FR-003**: Every OTHER behavior keeps the exact pre-#1542 contract: the
  misfire fires unless BOTH red and green evidence exist. The pinned bug
  #682 green-only honesty suite MUST stay green unchanged.
- **FR-004**: `zfa tdd make <id> --born-green` MUST advance
  `tdd/run-state.json` for the certified behavior when its recorded state
  is `blocked`: `blocked → done` (atomic save via `RunStateStore`). States
  with sound re-entry windows (`pending` promotes through the evidence
  reconciliation; `red` re-enters at make; `green`/`mocked` re-enter at
  refactor; `done` is terminal) are left untouched. A missing state file is
  a no-op (make never fabricates a run).
- **FR-005**: The born-green journal marker is ONE shared constant
  (`bornGreenEvidenceMarker` in `born_green.dart`) used by BOTH the writer
  (the `--born-green` append's `- evidence:` field) and the reader (the
  driver's refactor probe) — one wording family, no drift surface. The
  marker text lives OUTSIDE the evidence hash-chain payload (the `- evidence:`
  additive precedent, issue #959), so the chain contract is untouched.
- **FR-006**: The advancement is OBSERVED: the born-green transition prints
  the state line (`<id> blocked -> done`) so the operator sees the wedge
  close without opening the state file.

## Hard Constraints

- Fix ONLY the refactor evidence check and the born-green run-state
  advancement. Do NOT change the contract lane, the blocked verdict, or the
  state machine (`_reconcile`, `_stepsFor`, the #1007 blocked arm).
- Must not break refactor for non-contract/non-born-green behaviors (FR-003,
  scenario 5).
- Must pass `dart analyze` with no new warnings.
- Related: #1007 (contract lane blocked verdict), #1411 (born-green hand
  transition), #682 (evidence-beats-state bootstrap), #1324 (resume
  windows), #828 (evidence hash chain — untouched).

## Success Criteria (measurable)

- SC-1: A driver-level suite drives a contract-lane behavior from
  `blocked` + green evidence through refactor to `green` — `done` is
  unreachable for the green-only classes (the bug #682 reconcile rule
  demotes the `done` claim, keeping the behavior re-provable) — with
  `result=complete` and no `incomplete` misfire line.
- SC-2: A driver-level suite drives a behavior whose last green entry
  carries the born-green journal marker through refactor to `green` (the
  same #682 reconcile rule) — and a twin WITHOUT the marker still misfires
  byte-identically to the pre-#1542 message.
- SC-3: A make-level suite proves `make --born-green` on a `blocked` state
  file flips the behavior to `done` on disk (and prints the advancement);
  with no state file, the transition still exits 0 and writes none.
- SC-4: The full born-green contract flow completes: `blocked` state +
  born-green journal evidence reconciles to green and re-enters at refactor
  (never at make), completing the run without manual state surgery.
- SC-5: `dart analyze` reports zero new findings on the changed files; the
  full fast-tier TDD suite stays green.
