# Test List: 1669-graceful-exit-consumes-marker

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the interrupt marker file still exists on | AC-1 | PENDING |
| A2 | the marker is consumed — the drift | AC-2 | PENDING |
| A3 | the refusal consumes this run's own marker — a | AC-3 | PENDING |
| A4 | the marker proves the crash: the make adopts | AC-4 | PENDING |
| A5 | the marker | AC-5 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

The `kind` cell is the finder-kind taxonomy (issue #1140): the scenario verbs' predicted assertion classes — presence, absence, route-outcome, enabled-state, sequence — or `none` when no finder is derivable. `zfa tdd gen` selects the assertion template by it and refuses a row whose kind column drifted from the scenario prose; verify-red's kind gate (issue #959/#964) certifies on the same vocabulary.

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [declared: type marker, spec line 57]
route: A2 -> acceptance lane [declared: type marker, spec line 66]
route: A3 -> acceptance lane [declared: type marker, spec line 72]
route: A4 -> acceptance lane [declared: type marker, spec line 79]
route: A5 -> acceptance lane [declared: type marker, spec line 86]

