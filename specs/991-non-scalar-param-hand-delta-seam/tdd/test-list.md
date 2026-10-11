# Test List: 991-non-scalar-param-hand-delta-seam

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | make stops with `outcome=hand-delta-required` (exit 1, no green evidence appended) and the stop output names the EXACT edit: replace `_arg0()` in the generated test file with a representative `Object`, then re-run `zfa tdd make <behavior-id>`. | AC-1 | PENDING |
| A2 | make re-certifies red (or green) FROM THE UPDATED TEST via its drift check (the target test is re-run before generation — the pre-existing certified-red entry never skips that verification), and the cycle proceeds to generation and green. | AC-2 | PENDING |
| A3 | `_scalarLiteral` covers `Object` and the generated capture site passes `Object()` as the representative argument — no `_argN()` placeholder helper is emitted for an `Object`-typed param, so the common case never dead-ends into the hand-delta seam. | AC-3 | PENDING |
| A4 | the representative literals are unchanged (`'sample'`, `0`, `false`, `0.0`) — backward compatibility is preserved. | AC-4 | PENDING |
| A5 | the run reports the named hand step `stopped_at=<id>:hand` (the issue #1308 hand-step contract) and the remedy line names the exact edit — the generic `stopped_at=<id>:make` stop is reserved for genuinely unknown failures. | AC-5 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

The `kind` cell is the finder-kind taxonomy (issue #1140): the scenario verbs' predicted assertion classes — presence, absence, route-outcome, enabled-state, sequence — or `none` when no finder is derivable. `zfa tdd gen` selects the assertion template by it and refuses a row whose kind column drifted from the scenario prose; verify-red's kind gate (issue #959/#964) certifies on the same vocabulary.

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | `zfa tdd make` MUST detect the `_argN()` placeholder as the | FR-001 | PENDING |
| U2 | When the `_argN()` placeholder is diagnosed, make MUST stop | FR-002 | PENDING |
| U3 | The hand-delta seam (`outcome=hand-delta-required`) MUST | FR-003 | PENDING |
| U4 | `_scalarLiteral` in the behavior test writer MUST cover | FR-004 | PENDING |
| U5 | After the hand-edit, re-running make MUST re-verify the | FR-005 | PENDING |
| U6 | The run driver MUST treat a `hand-delta-required` make stop | FR-006 | PENDING |
| U7 | Scalar-typed contract params continue to work unchanged — | FR-007 | PENDING |

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [declared: type marker, spec line 27]
route: A2 -> acceptance lane [declared: type marker, spec line 29]
route: A3 -> acceptance lane [declared: type marker, spec line 31]
route: A4 -> acceptance lane [declared: type marker, spec line 33]
route: A5 -> acceptance lane [declared: type marker, spec line 35]
route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U4 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U5 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U6 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U7 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]

