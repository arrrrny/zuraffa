# Spec Fuzz — feature `004-login-ui`

Mutation testing for intent (spec 0967, VISION §7): the referee round. Every mutation below was applied to `spec.md`, the loop's pins were re-run, and the verdict records whether anything in the harness detects the mutation. A survived mutant is a proven spec weakness — the test suite does not pin the intent.

<!-- spec-fuzz
schema: spec-fuzz.v1
feature: 004-login-ui
gate: notAssessed
certified: false
mutations: 5
killed: 1
survived: 3
not_assessed: 1
seed: 0
budget: 5
restoration_verified: true
-->

## Gate

- gate: `notAssessed`
- certified: `false`

## Round

- seed: 0
- budget: 5
- candidates: 8
- operators: drop, drop-must-not, swap-literal, weaken, widen
- fuzz_was_run: true

## Mutations

| mutation_id | spec_line | operator | element | verdict | evidence |
| --- | --- | --- | --- | --- | --- |
| SM-001 | 25 | drop | AC-1:scenario | survived | no pin fired: the plan gates pass, the regenerated suite stays green against the committed implementation, and no committed assertion pins the original value(s) 1 — the test suite does not pin the intent |
| SM-002 | 27 | drop | AC-2:scenario | killed | P3:assertion — original value "@" is asserted at test/tdd/004-login-ui/a5_test.dart:2 |
| SM-003 | 29 | drop | AC-3:scenario | survived | no pin fired: the plan gates pass, the regenerated suite stays green against the committed implementation, and no committed assertion pins the original value(s) 3, 8 — the test suite does not pin the intent |
| SM-004 | 48 | drop | AC-6:scenario | survived | no pin fired: the plan gates pass, the regenerated suite stays green against the committed implementation, and no committed assertion pins the original value(s) 2 — the test suite does not pin the intent |
| SM-005 | 57 | swap-literal | FR-001:literal:`@` | notAssessed | the regenerated test for U1 failed to LOAD (issue #1045): 00:00 +0: loading /home/z/my-project/zuraffa/test/tdd/004-login-ui/u1_test.dart                                         … |

## Survived mutations (spec weaknesses)

- `SM-001` — AC-1:scenario (spec line 25)
  --> fix: pin the intent — assert the original value(s) 1 in the feature's tests, or tighten the statement so the loop re-derives a stronger assertion.
- `SM-003` — AC-3:scenario (spec line 29)
  --> fix: pin the intent — assert the original value(s) 3, 8 in the feature's tests, or tighten the statement so the loop re-derives a stronger assertion.
- `SM-004` — AC-6:scenario (spec line 48)
  --> fix: pin the intent — assert the original value(s) 2 in the feature's tests, or tighten the statement so the loop re-derives a stronger assertion.

## Restoration

- verified: `true`
- scope: 1 file(s)

## Ledger

- gap-001, gap-002, gap-003

## Evidence binding

- spec_hash: `sha256:0838b8931ded7cd6bfb90e7637558ba928bc4d3f6dac8315392a4a44a862ec7d`

