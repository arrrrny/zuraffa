# Bug Assessment: zfa tdd run cannot bootstrap from existing evidence — run-state starts all pending even when all done

- **Slug**: tdd-run-bootstrap-existing-evidence
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/682 (allowlisted host: github.com — fetched)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

GitHub issue #682 (opened against `arrrrny/zuraffa`): `zfa tdd run` cannot
bootstrap from an existing TDD project where all behaviors have already been
proven. Red+green evidence exists in `tdd/cycle-log.md` and a
`tdd/verification.md` records a PASS verdict for the full suite, but the
`run-state.json` lists every behavior as `pending` (or does not exist at all),
so the runner attempts to regenerate and re-verify every behavior — including
those already certified DONE — instead of skipping them. On the reporter's
brownfield package the re-generated stub subjects throw `UnimplementedError`,
verify-red/make fail, and the run stops at `U1:make` with a runner-error.

## Symptom

`zfa tdd run <feature>` on a brownfield feature with complete cycle-log
evidence re-drives the whole TDD cycle from `gen` and stops honestly-but-
wrongly at the first behavior's failing steps, instead of recognizing the
certified behaviors, skipping them, and completing the run. Expected: evidence
in `tdd/cycle-log.md` is the certification source of truth (FR-003), so a
missing or all-pending `run-state.json` must be bootstrapped from it.

## Reproduction

1. A feature directory `specs/<feature>/tdd/` has `test-list.md` with the
   behaviors, and `cycle-log.md` with a red AND a green section for every
   behavior id (a `tdd/verification.md` with a PASS verdict typically also
   exists).
2. Ensure `specs/<feature>/tdd/run-state.json` is absent (fresh/brownfield
   bootstrap) or carries every behavior as `"pending"`.
3. Run `zfa tdd run <feature>`.
4. Observed: the runner drives `gen` → `verify-red` → `make` for every
   behavior from scratch; against real brownfield subjects the stub
   `UnimplementedError` turns verify-red/make into failures and the run stops
   at `<first-id>:make` (runner-error). Expected: behaviors with red+green
   evidence are `done` and skipped; green-only → `green`; red-only → `red`;
   no evidence → `pending`.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/run_command.dart:411-443` — `RunCommand._reconcile`:
  the evidence-vs-state merge. Only a `claimed == BehaviorState.done` branch
  exists (demotion to the evidence-backed state). A `pending` claim — which is
  what `RunState.empty()` implies for every row (`run_command.dart:218`:
  `loaded ?? RunState.empty(feature)`) or what a hand-written all-pending
  state file asserts — is never promoted, even with complete evidence.
- `lib/src/plugins/tdd/models/run_state.dart:29-30` — `RunState.empty(feature)`
  seeds an empty `behaviorStates` map; `_reconcile` defaults missing rows to
  `pending` (`run_command.dart:419`), which the initial save
  (`run_command.dart:228-234`, `needsInitialSave` is true because
  `loaded == null`) then persists verbatim as an all-`pending` state file.
- `lib/src/plugins/tdd/services/cycle_evidence.dart:27-43` —
  `CycleEvidence.redEvidence()/greenEvidence()`: parses `tdd/cycle-log.md`
  `## ` sections carrying `- behavior: <id>` + `- kind: red|green`. Missing
  log → empty sets. This is the evidence source `_reconcile` already receives
  (`run_command.dart:216-222`) — no new IO is required for the fix.
- `lib/src/plugins/tdd/commands/run_command.dart:284-286,318-323,355-357` —
  the three phase loops consume the reconciled states (`done` skips, `green`
  re-enters at refactor, `red` re-enters at make); promoting states therefore
  composes with the existing two-phase driving (bugs #625/#635/#657) without
  touching the loops.
- `lib/src/plugins/tdd/commands/run_command.dart:236-240` — the
  `"N already done — skipping"` announcement reads the reconciled states, so a
  successful bootstrap is user-visible.

## Root Cause Hypothesis

High confidence. `_reconcile` implements only one direction of FR-003
("evidence beats state"): a `done` claim is demoted to the evidence-backed
state, but a `pending` claim is never promoted to the evidence-backed state.
Because `loaded == null` (no `run-state.json` yet) falls back to
`RunState.empty()` — whose missing rows reconcile to explicit `pending` — a
brownfield feature with complete evidence is indistinguishable, to the runner,
from a never-started feature. The runner then re-drives the full cycle and, on
real subjects, stops at the first failing step. The demotion branch already
contains the exact evidence→state mapping needed for promotion
(red+green→done, green→green, red→red, none→pending).

## Proposed Remediation

**Preferred**: extend `_reconcile` in
`lib/src/plugins/tdd/commands/run_command.dart` so the evidence-backed state
is computed for `pending` claims as well as `done` claims — the promotion
direction. Concretely: when `claimed == BehaviorState.done || claimed ==
BehaviorState.pending`, compute the evidence-backed state
(`hasRed && hasGreen` → done, `hasGreen` → green, `hasRed` → red, neither →
the claimed state unchanged: a `done` claim demotes to `pending` as today, a
`pending` claim stays `pending`). Claims of `red`/`green` keep their existing
resume semantics (re-enter at make / refactor respectively) and are untouched,
keeping the fix minimal and crash-resume behavior unchanged.

Refinements recorded during the red→green loop (2026-09-01, same session):

- **In-flight gate**: promotion applies only when the loaded state file
  carries NO in-flight marker (`state.inFlightBehaviorId == null`). A marked
  file describes an interrupted run that resumes by its claims (U23 /
  sc_014 A5 resume contracts); bootstrapping rows of a mid-resume file from
  evidence changed those contracts (observed as U23/A5 case-2 failures under
  a per-row exemption) while giving no bootstrap benefit — a genuine
  brownfield bootstrap never carries a marker. Demotion of `done` claims is
  untouched in all cases.
- **Green-only honesty**: a green-only-evidence behavior promotes to GREEN
  per the issue's mapping and re-enters at refactor, where the pre-existing
  evidence misfire guard (FR-003/FR-011) honestly stops the run naming the
  incomplete red evidence rather than fabricating certification. This is the
  existing contract, not new behavior; a test pins it so the bootstrap never
  silently fakes completion.

Rationale for promoting on explicit `pending` claims too (not only missing
rows): the issue's reproduction includes a state file that exists with all 26
behaviors `pending`; treating "pending" as "no contrary claim" is exactly
FR-003's evidence-beats-state contract, and a user who genuinely wants to
re-prove a behavior deletes its cycle-log evidence (the certification source),
not the state file.

The initial `needsInitialSave` logic (`run_command.dart:224-234`) already
persists the reconciled state when `loaded == null` or when the JSON changes,
so promoted states are written back without further changes; the
`"N already done — skipping"` line and the summary counters then reflect the
bootstrap for free.

**Alternatives**:

- Only promote when `loaded == null` (bootstrap-only). Rejected: it forks the
  reconcile semantics into two modes for no behavioral gain — an explicit
  all-pending file (the issue's own repro state) would stay broken, and
  FR-003 gives evidence priority over claims in both directions anyway.
- Auto-create a hand-built `run-state.json` in a separate bootstrap command
  (e.g. `zfa tdd run --bootstrap`). Rejected: new surface, new docs, and the
  reporter's workaround already exists (hand-writing the file); the one-line
  reconcile extension fixes the actual contract violation instead.

**Files likely to change**:

- `lib/src/plugins/tdd/commands/run_command.dart` (`_reconcile` + its doc
  comment)
- `test/plugins/tdd/run_command_test.dart` (bootstrap coverage)

**Tests to add or update**:

- Bootstrap with NO `run-state.json` and mixed evidence: red+green → skipped
  (done), green-only → re-enters at refactor, red-only → re-enters at make;
  run completes exit 0; state file persisted with the promoted states.
- Bootstrap with an all-`pending` `run-state.json` and full red+green
  evidence: zero step invocations, everything promoted to `done`, run
  completes exit 0.
- Guard: no evidence → still `pending` → full cycle driven (no behavior
  change for greenfield runs; covered by existing U19).

## Risks & Considerations

- Behavior change is intentional and user-facing: a re-run after evidence was
  hand-edited into `cycle-log.md` now skips certified behaviors. This is the
  FR-003 contract ("evidence beats state") applied consistently; the demotion
  direction already shipped this semantics in the opposite direction.
- A user who wants to force a full re-drive must clear the cycle-log evidence
  (or the specific sections), not just the state file. Document this in the
  `_reconcile` doc comment so the contract is discoverable.
- The misfire guard (`_evidenceMisfire`, FR-003/FR-011) is unaffected: it
  polices steps that were just spawned, not reconciled claims.
- No API breakage: `_reconcile` is private; `RunState`, the store format, and
  the CLI surface are unchanged.

## Open Questions

- None. The issue supplies the expected state mapping, the code path checks
  out on `master` (387f1f29), and the existing fixture helpers
  (`seedRedEvidence`/`seedGreenEvidence`/`seedRunState`) cover the test needs.
