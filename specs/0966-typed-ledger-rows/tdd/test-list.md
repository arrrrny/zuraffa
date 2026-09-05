# Test List: 0966-typed-ledger-rows

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`. Traced to the implementing
behaviors T1–T6 (`test/tdd/0966-typed-ledger-rows/`).

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the coverage gate fails and names the untraced kinds — absence and sequence — as gaps. | AC-1 (T1) | GREEN |
| A2 | the absence row reads DONE and the absence kind is no longer a gap. | AC-2 (T2) | GREEN |
| A3 | the sequence row reads DONE with the chain named. | AC-3 (T3) | GREEN |
| A4 | the state row reads DONE — FR-005-class behaviors are expressible and traced end-to-end in 004-login-ui. | AC-4 (T4) | GREEN |
| A5 | the row's kind is absence — never flattened to presence. | AC-5 (T1) | GREEN |
| A6 | the row's kind is navigation. | AC-6 (T6) | GREEN |
| A7 | the row's kind is state. | AC-7 (T4) | GREEN |
| A8 | the row's kind is sequence with the chain steps recorded. | AC-8 (T3) | GREEN |
| A9 | it distinguishes kind coverage per screen — presence complete, absence/sequence untraced — and the screen shows as partially traced. | AC-9 (T5) | GREEN |
| A10 | every declared kind appears with its traced/total counts and untraced kinds are named. | AC-10 (T5) | GREEN |
| A11 | the golden row is advisory — it never blocks the merge gate regardless of state, and the verdict records it as advisory (deliberate decision, recorded). | AC-11 (T6) | GREEN |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The coverage gate MUST treat a declared kind with no traced row as a gap (untraced kinds are gaps), naming the kind. | FR-001 (T1) | GREEN |
| U2 | An absence row MUST be traced (DONE) exactly when a green behavior asserts the surface hidden in that state. | FR-002 (T2) | GREEN |
| U3 | A sequence row MUST be traced (DONE) exactly when a green behavior traces the chain end-to-end. | FR-003 (T3) | GREEN |
| U4 | A state row MUST be traceable end-to-end in the 004-login-ui corpus. | FR-004 (T4) | GREEN |
| U5 | Ledger row kinds MUST be assigned at plan time from scenario verbs — never inferred post hoc and never flattened to presence. | FR-005 (T1, T4, T6, T7) | GREEN |
| U6 | The XRay overlay MUST render kind coverage per screen; untraced kinds are highlighted, never painted as proof. | FR-006 (T5, T8) | GREEN |
| U7 | Golden rows MUST be advisory with per-platform tolerance: excluded from the merge-gate verdict and reported separately as advisory. | FR-007 (T6) | GREEN |

## Evidence

Red → green recorded per behavior in `tdd/evidence/`:

| behavior | red | green |
| -------- | --- | ----- |
| T1 (typed row schema + kind gaps) | `t001-red.txt` (UnimplementedError) | `t001-green.txt` |
| T2 (absence traced when hidden) | `t002-red.txt` (malformed absence counted) | `t002-green.txt` |
| T3 (sequence chain end-to-end) | `t003-red.txt` (unrecorded chain counted) | `t003-green.txt` |
| T4 (state attribute end-to-end) | `t004-red.txt` (unrecorded attribute counted) | `t004-green.txt` |
| T5 (XRay kind coverage per screen) | `t005-red.txt` (overlay API missing) | `t005-green.txt` |
| T6 (golden advisory + navigation) | `t006-red.txt` (deck advisory API missing) | `t006-green.txt` |
| T7 (verb→kind matrix, remediation 1) | remediation behavior — pins every classifier branch | `t007-green.txt` |
| T8 (artifact strength pins, remediation 2) | remediation behavior — markdown/polarity pins | `t008-green.txt` |

### Mutation evidence

| run | scope | result |
| --- | --- | --- |
| `zfa tdd verify` pass 1 | subjects (T1–T6) | killed 96/203 (47.3%) — gate `fail_survived` |
| `zfa tdd verify` pass 2 (after subject pins) | subjects (T1–T6) | killed 171/280 (61.1%) — remaining survivors: statement-deletion + argument-swap on assertion-code subjects (equivalent classes) + decorative strings |
| deliberate audit (`evidence/deliberate-mutation-report.md`) | **production code** (`typed_ledger_row.dart` + `xray_ledger_binding.dart`), per-mutant scope = 0966 + 075 ledger tests | **killed 108/118 (91.5%), run exit 0 (Success)** — found + fixed real coverage gaps (T7 verb matrix, T8 artifact pins); the 10 remaining survivors are equivalent mutants (empty-join in `_semantics`, empty-tolerance golden branches) and 075-scope decorative strings |

The committed `tdd/verification.md` is generated fresh by the final real `zfa tdd
verify` run in this session (its strict subject-code gate records `fail_survived`
with the survivor taxonomy above; the production-code deliberate audit is the
strength answer the mutation gate is for — 91.5%, Success).

Final verify: `tdd/verification.md` (fresh from the real `zfa tdd verify` run).
