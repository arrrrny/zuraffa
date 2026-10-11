# Bug Fix: #1626 — acceptance vacuous-green refusal names the hand step

- **Slug**: 1626-acceptance-vacuous-remedy
- **Branch**: `fix/1626-acceptance-vacuous-remedy`
- **Issue**: https://github.com/arrrrny/zuraffa/issues/1626
- **Fix mode**: TDD (red → green → refactor), `tdd_enabled` bug workflow
- **Surface kind**: refusal WORDING only — the #1488 gate, the #1512
  contract-shape ignore, and the hand-step mechanics are untouched.

## Root cause (confirmed in source)

Two refusal surfaces borrowed the FALLBACK-routed remedy for acceptance rows:

1. `make_command.dart` step 3c — the acceptance branch rendered
   `vacuousGuardFallbackRemedyFor(...)` (traces/re-plan/re-gen).
2. `run_driver_core.dart` make-`vacuous-green` arm — the marker-absent branch
   rendered `_vacuousFallbackRemedy(...)` for every row, acceptance included.

The acceptance lane ignores the contract shape BY DESIGN (#1512: "the
contract-derived shape rides ONLY the plain-function pair (unit lane)"), so
`traces:` → re-plan → re-gen can never produce a real acceptance assertion —
the regenerated test stays guard-only and the #1488 gate refuses again: the
measured loop. The path that works (the #1411 designed hand step: outcome
assertion OUTSIDE the capture, scenario runner implemented, attestation header,
`--born-green`) is exactly the shape the repo's own fixture
`test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart` documents
(helper `outcomeAssertedAcceptanceTest`) — the runtime messages never adopted it.

## The fix (3 files + tests)

1. **`lib/src/plugins/tdd/services/vacuous_guard.dart`** — new ONE wording
   source `acceptanceVacuousHandStepRemedyFor({behaviorId, testPath,
   subjectPath})`: names the hand step ("write an assertion on the observable
   outcome OUTSIDE the capture in `<test path>` (the guard-only test is the RED
   surface), implement the scenario runner in `<subject path>`, add the
   attestation header (`<handStepHeader(id)>`), then run
   `zfa tdd make <id> --born-green`") and states the WHY ("traces/re-plan/re-gen
   cannot produce a real acceptance assertion (the acceptance lane ignores the
   contract shape, issue #1512)"). Renders the #1411 attestation header verbatim
   so the copy step is mechanical.
2. **`lib/src/plugins/tdd/commands/make_command.dart`** (step 3c) — the
   acceptance branch renders the new remedy with both registry paths
   (project-relative posix via the existing `_relPosix`); the unit branch keeps
   its outcome-assertion wording byte-for-byte.
3. **`lib/src/plugins/tdd/commands/run_driver_core.dart`** (make-vacuous-green
   marker-absent arm) — `row.kind == BehaviorKind.acceptance` → a new acceptance
   explanation line (naming `acceptanceFallbackGuardToken`, the #1512 why) + the
   new remedy line; UNIT/fallback rows keep `_vacuousFallbackRemedy` (the #1483
   wording) unchanged. The stop stays `stopped_at=<id>:make` (the honest
   fallback-routed class, #1512) — the machine contract is untouched. Subject
   path resolves through the artifact registry record (the single path
   contract) and fails open to the conventional gen layout
   `lib/tdd/<feature>/<snake-id>_subject.dart` when no record exists
   (`_acceptanceSubjectRelPath`).

## Explicit non-changes (hard constraints honored)

- The #1488 vacuous-green gate (`contentIsVacuousGreen`, the 3c scope, the run
  driver's stop semantics) — unchanged.
- The #1512 contract-shape ignore (`behavior_test_writer.dart` acceptance
  rendering, marker-absence discipline) — unchanged; the gen-time guard-only
  warning stays unit-scoped, so it never printed the broken remedy.
- The hand-step mechanics (`--born-green` gates, attestation header, subject
  hash binding) — unchanged.

## Test map (red → green, real runs)

See `tdd/test-list.md` (U-1626-w1/a1/a2/a3/d1/d2/p1/p2) and
`.specify/bugs/1626-acceptance-vacuous-remedy/red-evidence.md` for the verbatim
pre-fix failures. Post-fix: all 8 behaviors GREEN — the two new suites
(`test/plugins/tdd/bug_1626_acceptance_vacuous_remedy_test.dart` +4,
`test/plugins/tdd/bug_1626_acceptance_remedy_driver_test.dart` +2) and the
re-pointed #1488 pin suite (+5, with A2/A3/U1 proving the untouched contracts).
Neighbor suites pinning the shared wording (#1259, #1308, #1320, #1483
shape+driver, #1518 seam+forward-driver) all pass unchanged.
