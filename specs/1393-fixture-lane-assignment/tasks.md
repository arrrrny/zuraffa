# Tasks: 1393-fixture-lane-assignment

**Input**: Design documents from `/specs/1393-fixture-lane-assignment/`
**Prerequisites**: plan.md ✓, spec.md ✓

## Format

- `[P]` = can run in parallel with other `[P]` tasks in the same phase
- Every behavior task is gated by a failing test (TDD — see tdd/test-list.md)

## Phase 1 — TDD red (pins first)

- [x] T001. [behavior: B1] Write the structural pin suite
      `test/plugins/tdd/commands/bug_1393_fixture_lane_pin_test.dart`
      (B1 U1-not-CORE, B2 engine-expressible unit, B3 strict Skin Contract
      parse, B4 committed split classification) and capture the red run
      against the shipped fixture: `+1 -3` (B1/B2/B4 red). Traces FR-001 /
      AS-1 / SC-001.
- [x] T002. Reproduce the issue's engine stop on the shipped fixture
      (`zfa tdd run 004-login-ui --project example`): A1/A2 make
      `unexpressible` → deferred; U1 make `vacuous-green` →
      `stopped_at=U1:make`. Recorded as red evidence. Traces AS-3 / SC-002.

## Phase 2 — Fixture re-split (the data fix)

- [x] T003. Re-split `example/specs/004-login-ui/spec.md`: move U1 from CORE
      to SKIN in `## Lanes` (CORE `[A1, A2, U2]`, SKIN `[W1, U1, A3-A7]`).
      Traces FR-001 / FR-003.
- [x] T004. Add FR-002 (credential-verdict submit gate) with
      `traces: LoginValidation.isSubmittable` and the declared
      **Function** row `LoginValidation: isSubmittable(String email,
      String password) -> bool` under Layer Contracts. Traces FR-002.
- [x] T005. Verify the `## Skin Contract` yaml with the strict production
      parser (already repaired on master per spec 1377; B3 green guards it).
      Traces FR-004 / AS-4 (US2).

## Phase 3 — Regenerate + drive the cycle

- [x] T006. [P] `zfa tdd plan 004-login-ui --project example` — routing
      provenance: `U2 -> unit lane (func surface) [declared: contract row:
      LoginValidation]`; commit the regenerated lane plans, meta-index,
      traceability, artifacts registry, provenance ledger. Traces FR-003.
- [x] T007. [P] `zfa tdd split 004-login-ui --force --project example` — the
      committed split receipt carries the re-split classification
      (A1/A2/U2 CORE; W1/U1/A3-A7 SKIN). Traces FR-003 / AS-1.
- [x] T008. `zfa tdd run 004-login-ui --project example` — engine half green
      unattended: U2 gen → verify-red (certified) → make (func scaffold
      green); A1/A2 make → spec 052 composition against the green U2 anchor
      → green; refactor pass clean; `04-engine-receipt.json` verdict green,
      result complete, stopped_at null, done 3/3. Commit the run evidence
      (gen pairs, cycle log, engine receipt). Traces AS-3 / SC-002 / EPIC
      #1012 exit criterion 4.
- [x] T009. Pin suite green against the re-split fixture: 4/4. Traces
      SC-001.

## Phase 4 — Polish

- [x] T010. `dart format` on every file this fix adds or changes — zero
      formatting diffs; `dart analyze` — no issues on the pin suite and the
      six new fixture files. Traces SC-003.
- [x] T011. Commit the SDD artifacts (spec.md, plan.md, tasks.md,
      tdd/test-list.md, tdd/verification.md, tdd/cycle-log.md) with the fix.

## Dependencies

T001 → T003 → (T004, T005) → (T006, T007) → T008 → T009 → T010 → T011.
The red pins (T001) gate the re-split; the plan/split regeneration
(T006/T007) gates the driven cycle (T008).
