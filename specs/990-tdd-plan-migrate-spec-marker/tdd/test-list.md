# Test List: 990-tdd-plan-migrate-spec-marker

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the latest known template version is inserted at the top of `spec.md`, the migration is reported on stdout, and the test list is generated in the same run. | AC-1 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The plan command accepts a `--migrate-spec` flag that migrates a non-conformant spec to the latest known template version and then proceeds with the normal plan flow. | FR-001 | PENDING |
| U2 | A missing (non-fenced) `Template Version` marker is injected at the top of the spec frontmatter, followed by a blank line, with every other byte of the spec preserved verbatim. | FR-002 | PENDING |
| U3 | A stale or unknown `Template Version` marker is refreshed in place to the latest known template version, and a marker mentioned only inside a fenced code block is never treated as the pin nor rewritten. | FR-003 | PENDING |
| U4 | Migration is idempotent — a spec already pinning a known template version is left byte-identical and no migration notice is printed. | FR-004 | PENDING |
| U5 | The contract drift gate itself is unchanged — without `--migrate-spec`, a missing or unknown marker still exits 3 with the fix line, no artifacts, and the spec file is never mutated. | FR-005 | PENDING |

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U4 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U5 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]

