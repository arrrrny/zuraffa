# Test List: 0969-tdd-a-plus-upgrade

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the final stdout | AC-1 | PENDING |
| A2 | the output is | AC-2 | PENDING |
| A3 | each generated artifact is | AC-3 | PENDING |
| A4 | the proof preflight refuses with a | AC-4 | PENDING |
| A5 | `cli.md` carries the full `zfa tdd` command table and | AC-5 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | Every `zfa tdd` subcommand accepts `--json` and, when the | FR-001 | PENDING |
| U2 | The envelope schema is `verdict.v1` with the keys | FR-002 | PENDING |
| U3 | A test asserts the exact envelope schema for at least | FR-003 | PENDING |
| U4 | `zfa tdd verdicts --schema` prints the envelope schema | FR-004 | PENDING |
| U5 | The generation verbs gen, make, view, func, wire and | FR-005 | PENDING |
| U6 | `zfa tdd verify` runs the proof preflight (`zfa proof | FR-006 | PENDING |
| U7 | The last-line machine grammar is unified: exactly one | FR-007 | PENDING |
| U8 | openwiki `cli.md` documents the tdd command table and | FR-008 | PENDING |

## Key entities

| entity | fields |
| ------ | ------ |
| VerdictEnvelope |  |

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A2 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A3 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A4 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A5 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U4 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U5 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U6 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U7 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U8 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]

