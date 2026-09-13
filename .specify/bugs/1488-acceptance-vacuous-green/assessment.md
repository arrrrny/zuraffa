# Assessment — #1488 acceptance lane certifies vacuous greens

Date: 2026-09-13
Branch: `fix/1488-acceptance-vacuous-green`
Scope: the vacuous-green detection scope in `make_command.dart` ONLY —
`contentIsVacuousGreen` itself is UNCHANGED (the hard constraint of this
fix).

## Evidence

- `zfa tdd run 001-todo-app --timeout 25`: A9 gen ok → verify-red certified
  → make certifies GREEN on a guard-only assertion set; the run reports
  `green=1` — a proof-free success persisted into run state.
- Reproduced at the make level (the make-level pin is the precise unit):
  `test/plugins/tdd/bug_1488_acceptance_vacuous_green_test.dart` A1 — an
  acceptance row with certified red + a non-throwing subject + a guard-only
  test certified `outcome=skipped` (green evidence appended, exit 0)
  pre-fix. RED evidence captured pre-fix: exit 0, `outcome=skipped`,
  `## Cycle: A-1488 (green)` appended.

## Root cause

`make_command.dart` step 3c gates the #1259 vacuous-green refusal on
`vacuousRowKind == BehaviorKind.unit` only. `contentIsVacuousGreen`
(vacuous_guard.dart) already detects the acceptance guard-only shape — its
content backstop strips the guard-shaped expects (including the
`isNot(throwsA(isA<UnimplementedError>()))` variant the acceptance lane
emits) and counts the remainder; zero remaining expects = vacuous. The
detection existed; the acceptance lane never called it.

The make flow an acceptance row took pre-fix:

1. step 3c gate — skipped (kind is acceptance, gate is unit-only);
2. step 4 drift check — the guard-only test PASSES against the
   implemented/composed subject (`alreadyGreen = true`);
3. the #694 skip transition — green evidence appended, `outcome=skipped`,
   exit 0. (Or, from a red start: generation planning → composition
   fallback → post-compose re-run → `outcome=green`.)

## Why widening the gate is safe for the honest lanes

- **Unit lane unchanged**: the gate keeps the unit branch; U1/U2 pins of
  `bug_1259_vacuous_green_test.dart` pass byte-for-byte.
- **Spec-052 compose-fallback tests unaffected**: every acceptance fixture
  that expects green (A13/U19, A13b, #873) seeds
  `TddFixture.subjectDrivenTest` — a REAL `expect(..., equals(42))`
  assertion. The #1345 placeholder re-drive fixtures are explicitly
  "NOT guard-only, so the #1259 vacuous-green gate does not pre-empt the
  drift check" (their own comment). Verified: `bug_1345` passes post-fix.
- **Kindless/legacy rows keep failing open**: no resolvable kind → no
  refusal (the #1259 fail-open contract). Pinned by `bug_1488` A3.
- **Run driver already prepared**: `run_driver_core.dart` handles
  `step == 'make' && outcome == 'vacuous-green'` — marker-absent tests
  (all acceptance tests, per #1512) stop as `stopped_at=<id>:make` with
  the fallback remedy. The make refusal lands on an existing, honest run
  stop — no new run-driver state.

## Two legacy pins inverted (with citations)

- `bug_1259_vacuous_green_test.dart` U3 — pinned the legacy skip
  transition for acceptance guard-only rows. Inverted to pin the refusal
  (cites #1488).
- `bug_1162_bug_subject_green_path_test.dart` A-1162e — pinned that an
  unexpressible acceptance make composes against stub-only unit subjects
  and certifies green. Inverted to pin the pre-generation refusal
  (cites #1488): the gate now fires at step 3c BEFORE generation
  planning, so the compose step never runs for a guard-only test.

## Remediation

Widen the gate: `vacuousRowKind == BehaviorKind.unit ||
vacuousRowKind == BehaviorKind.acceptance`. Update the step-3c comment and
the stale `behavior_test_writer.dart` capture comment (comment-only; the
old text documented the removed unit-scoped design). No other logic
touched.
