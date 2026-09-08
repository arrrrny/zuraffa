# Test List: 1309-stale-lane-plans-after-spec-edit

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | plan reports the stale split, regenerates `tdd/04-ENGINE.md` and `tdd/04-SKIN.md` from the current behavior set, and the regenerated engine plan carries the new requirement's behavior row. | AC-1 | PENDING |
| A2 | the deleted requirement's ghost row no longer appears in any lane plan file and the shared reader resolves the current behavior set only. | AC-2 | PENDING |
| A3 | the split re-runs, overwriting the lane plans, the meta-index, and the receipt with a fresh receipt recording the current spec state. | AC-3 | PENDING |
| A4 | the refusal names the actual remedy: `zfa tdd split --force` to re-split, or `zfa tdd plan` to refresh the lane plans from the current spec. | AC-4 | PENDING |
| A5 | no staleness is reported and the lane plans still reflect the current behavior set after the run. | AC-5 | PENDING |
| A6 | the legacy single-file plan is written exactly as before and no lane plan files appear. | AC-6 | PENDING |
| A7 | the staleness is still detected through the mtime comparison and the lane plans are regenerated. | AC-7 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

The `kind` cell is the finder-kind taxonomy (issue #1140): the scenario verbs' predicted assertion classes — presence, absence, route-outcome, enabled-state, sequence — or `none` when no finder is derivable. `zfa tdd gen` selects the assertion template by it and refuses a row whose kind column drifted from the scenario prose; verify-red's kind gate (issue #959/#964) certifies on the same vocabulary.

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The split receipt records the sha256 digest of the spec content (`spec_hash`) and the spec file's modification time (`spec_mtime`) captured at split time, so a later plan run can compare the current spec against the state the split derived from. | FR-001 | PENDING |
| U2 | When a split receipt exists and the spec declares no lanes section, `zfa tdd plan` regenerates the lane plans (`tdd/04-ENGINE.md`, `tdd/04-SKIN.md`, `tdd/04-CONTRACT.md`) and the lane meta-index from the current behavior set using the same kind heuristic the split command applies, so deleted behaviors disappear and added behaviors appear in the regenerated files. | FR-002 | PENDING |
| U3 | When the spec changed since the receipt was written (the recorded `spec_hash` differs from the current spec digest, or the receipt carries no hash and the spec mtime is newer than the receipt's split timestamp), plan reports the stale split before writing, and after writing it refreshes the receipt's spec digest fields plus `refreshed_at`, `refreshed_by` and `refreshed_rows` audit entries so the detection fires only on the next real spec change. | FR-003 | PENDING |
| U4 | After `zfa tdd plan` or `zfa tdd split` completes on a receipt-bearing feature, every lane plan file reflects the current behavior set in the spec, no stale requirement rows remain, and the lane plan modification times are at least the spec's modification time. | FR-004 | PENDING |
| U5 | The split command accepts a force flag that re-splits a receipt-bearing feature: the behavior rows re-read through the shared reader, the lane plans and meta-index overwritten, and a fresh receipt written recording the current spec digest and mtime. | FR-005 | PENDING |
| U6 | The one-shot refusal names the actual remedy — use the force flag to re-split, or run plan to refresh the lane plans from the current spec — instead of deadlocking with the plan command's lane guidance. | FR-006 | PENDING |
| U7 | Features never split plan exactly as before; features whose specs declare the lanes section plan through the existing lane path unchanged; the staleness detection fires only when a split receipt exists AND the spec changed since the receipt was written. | FR-007 | PENDING |

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A2 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A3 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A4 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A5 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A6 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A7 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U4 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U5 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U6 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U7 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]

