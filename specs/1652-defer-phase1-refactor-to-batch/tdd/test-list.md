# Test List: 1652-defer-phase1-refactor-to-batch

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the driver defers the refactor to the phase-2 batch pass instead of spawning any refactor subprocess in phase 1, printing the existing deferral line. | AC-1 | PENDING |
| A2 | the batch spawns one refactor per green behavior, each carrying the pass-batch opt-in, and the full-suite gate still fires at most once per lane per run. | AC-2 | PENDING |
| A3 | the refactor runs in phase 1 exactly as before this feature, carrying the pass-batch opt-in. | AC-3 | PENDING |
| A4 | neither shape's refactor behavior changes and neither ever reaches the new deferral arm. | AC-4 | PENDING |
| A5 | the already-made behaviors keep their green state with deferred refactors and no phase-2b pass runs. | AC-5 | PENDING |

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

route: A1 -> acceptance lane [declared: type marker, spec line 74]
route: A2 -> acceptance lane [declared: type marker, spec line 81]
route: A3 -> acceptance lane [declared: type marker, spec line 89]
route: A4 -> acceptance lane [declared: type marker, spec line 98]
route: A5 -> acceptance lane [declared: type marker, spec line 104]

