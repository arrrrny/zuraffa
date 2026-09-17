# Test List: zero-route-gorouter-launch

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A3 | it carries the same `errorBuilder` / empty-table fallback alongside the observer. | AC-3 | PENDING |
| A4 | the runtime empty-check leaves the real route table untouched (fallback only fires on an empty table). | AC-4 | PENDING |
| A5 | the placeholder behavior is unaffected because the fallback is runtime-side in the generated router. | AC-5 | PENDING |
| A6 | it stays router-free (no Flutter imports) — only the Flutter flavor gains router coverage. | AC-6 | PENDING |
| A8 | they assert the new `errorBuilder` / fallback output and pass. | AC-8 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

The `kind` cell is the finder-kind taxonomy (issue #1140): the scenario verbs' predicted assertion classes — presence, absence, route-outcome, enabled-state, sequence — or `none` when no finder is derivable. `zfa tdd gen` selects the assertion template by it and refuses a row whose kind column drifted from the scenario prose; verify-red's kind gate (issue #959/#964) certifies on the same vocabulary.

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |
| A1 | the emitted GoRouter installs an `errorBuilder` that renders a placeholder (Scaffold with the app title and a "no routes yet — generate views with `zfa route <Entity>`" hint) and a runtime empty-table fallback so `getAllRoutes().isEmpty` swaps in a placeholder `GoRoute(path: '/')` at router-construction time. | presence | AC-1 | PENDING |
| A2 | the resolution renders the placeholder instead of throwing `no route for location: /`. | none | AC-2 | PENDING |
| A7 | the smoke test still constructs the DI container AND also pumps the app shell and asserts the initial `/` resolves to the placeholder screen. | none | AC-7 | PENDING |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> widget lane [declared: type marker, spec line 14]
route: A2 -> widget lane [declared: type marker, spec line 16]
route: A3 -> acceptance lane [declared: type marker, spec line 18]
route: A4 -> acceptance lane [declared: type marker, spec line 20]
route: A5 -> acceptance lane [declared: type marker, spec line 25]
route: A6 -> acceptance lane [declared: type marker, spec line 27]
route: A7 -> widget lane [declared: type marker, spec line 32]
route: A8 -> acceptance lane [declared: type marker, spec line 34]

