# Test List: 1391-realize-mock-skip-foreign-fixtures

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the gate exits 0 with verdict `certified`, runs all three real cases, prints `skipped manifest.json (schema 1)` and `skipped mock-cert.Login.json (schema 1)`, and the receipt carries the 3 method records — no runner-error, no hand removal of registry files. | AC-1 | PENDING |
| A2 | the scan skips it and logs `skipped <name> (schema <x>)` where `<name>` is the file basename and `<x>` is the document's schema value rendered verbatim (or `unknown` when absent or the file is not parseable JSON) — the scan never fails on a foreign document. | AC-2 | PENDING |
| A3 | it fails with `result=blocked` (exit 1) naming that no `realize-diff.v1` contract cases remain after the foreign documents were skipped — an empty surface is never certified. | AC-3 | PENDING |
| A4 | the behavior is unchanged: no `skipped` lines, the same per-method differential, the same receipt and verdict as before this change (backward compatibility). | AC-4 | PENDING |
| A5 | the scan still fails closed with the existing "fix the fixture before certifying" validation — the skip path is reserved for foreign documents, and a broken contract case of the gate's own schema remains a hard error. | AC-5 | PENDING |

## Outer loop: widget behaviors

UI acceptance scenarios (bug #830): asserted through a testWidgets pair — a view-builder subject stub plus a widget test that pumps the view and asserts the scenario.

The `kind` cell is the finder-kind taxonomy (issue #1140): the scenario verbs' predicted assertion classes — presence, absence, route-outcome, enabled-state, sequence — or `none` when no finder is derivable. `zfa tdd gen` selects the assertion template by it and refuses a row whose kind column drifted from the scenario prose; verify-red's kind gate (issue #959/#964) certifies on the same vocabulary.

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | realize-mock's fixture scan MUST classify each `.json` | FR-001 | PENDING |
| U2 | For every scanned document whose schema is not the exact | FR-002 | PENDING |
| U3 | `manifest.json` and `mock-cert.*.json` (the #832 registry | FR-003 | PENDING |
| U4 | A document stamped `realize-diff.v1` that is malformed | FR-004 | PENDING |
| U5 | When every scanned document was skipped (zero contract | FR-005 | PENDING |
| U6 | Backward compatibility: a feature whose fixtures directory | FR-006 | PENDING |
| U7 | Scope guard: ONLY realize-mock's fixture scan changes. The | FR-007 | PENDING |

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [declared: type marker, spec line 32]
route: A2 -> acceptance lane [declared: type marker, spec line 34]
route: A3 -> acceptance lane [declared: type marker, spec line 36]
route: A4 -> acceptance lane [declared: type marker, spec line 38]
route: A5 -> acceptance lane [declared: type marker, spec line 40]
route: U1 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U2 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U3 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U4 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U5 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U6 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]
route: U7 -> unit lane [fallback: legacy description classifier matched — trace FR to a declared contract row]

