# Test List: 1530-generated-code-fails-own-gate

## Outer loop: acceptance behaviors

One per acceptance scenario in `spec.md`. Task-id mapping per
`tasks.md` traceability (A1→A-1530-1 ... A12→A-1530-13).

| id | behavior | traces | task | state |
| -- | -------- | ------ | ---- | ----- |
| A1 | Generated datasource/mock files import the framework barrels with NO `hide` combinator when the target has no resolvable zuraffa barrel (no `hide Task, TaskPatch` anywhere). | AC US1-1 / SC-001 | T004, T008 | PENDING |
| A2 | With a resolved fixture barrel, the emitted hide list contains only verified exports (`QueryParams` kept, `Product`/`ProductPatch` dropped). | AC US1-2 / SC-002 | T005 | PENDING |
| A3 | `show`/`hide` combinators on export lines shape the verified surface: shown-only contributes, hidden subtracts. | AC US1-3 / SC-002 | T006 | PENDING |
| A4 | The #942 collision case (entity named like a verified framework export) still emits the verified hide — compiling output preserved. | AC US1-4 / FR-010 | T005 | PENDING |
| A5 | A run whose files import `package:zuraffa/...` on a pubspec lacking the declaration adds `zuraffa: ^6.0.0` under `dependencies:`. | AC US2-1 / SC-003 | T009, T016 | PENDING |
| A6 | Re-run / already-declared pubspec → byte-identical file (idempotent). | AC US2-2 / SC-003 | T010 | PENDING |
| A7 | Comments, blank lines, entry order preserved around the insertion. | AC US2-3 | T011 | PENDING |
| A8 | Inline-mapping shape refused loudly; unparseable YAML refused; override-only still added under `dependencies:`. | AC US2-4 | T012 | PENDING |
| A9 | Files importing no `package:zuraffa/` URI → pubspec untouched. | AC US2-5 | T013, T015 | PENDING |
| A10 | A `green-with-failed-build` receipt prints the analyzer `warning -` lines verbatim (capped + remainder). | AC US3-1 / SC-004 | T017 | PENDING |
| A11 | No `warning -` lines in the tolerated output → explicit no-warnings line. | AC US3-3 / SC-004 | T018 | PENDING |
| A12 | Build output with `error -` lines keeps the #942 refusal (`generation-error`) — receipt change never re-grades. | AC US3-2 / FR-009 | T019 | PENDING |

## Outer loop: widget behaviors

No widget surface: the dogfood gate is driven by the pure-Dart CLI
(spec Lanes — CORE only).

| id | behavior | kind | traces | state |
| -- | -------- | ---- | ------ | ----- |

## Inner loop: unit behaviors

One per testable functional requirement cluster in `spec.md`.

| id | behavior | traces | task | state |
| -- | -------- | ------ | ---- | ----- |
| U1 | All emission sites route hide candidates through the (FR-001..003) filter; filtered-empty emits no combinator (datasource local/remote/interface, mock datasource, failing mock provider, provider, sqlite, repository interface, usecase). | FR-004 | T008 | PENDING |
| U2 | The ensure rides the make pubsync post-pass: invoked iff a written file imports `package:zuraffa/`; receipt line names the declaration; other packages keep the #1265 auto-add / #1190 warning flows. | FR-005, FR-006, FR-007 | T015 | PENDING |
| U3 | Receipt warnings extraction uses the #1407 regex shape and cap contract; grading code paths untouched. | FR-008 | T017, T020 | PENDING |
| U4 | Seeded-path byte-preservation: verified hides emitted exactly as before the change (regression guard across the barrel-exports + entity-utils + builder lanes). | FR-010 | T005, T021 | PENDING |

## Routing provenance

Per-behavior routing decisions (issue #951): declared `**Type**` markers
route every acceptance row to the acceptance lane; FR traces route the
unit rows to the unit lane (declared Layer Contract rows: `BarrelExports`
lines 176-177, `ZuraffaEnsure` line 178, `MakeReceipt` line 179).

route: A1 -> acceptance lane [declared: type marker, spec line 72]
route: A2 -> acceptance lane [declared: type marker, spec line 74]
route: A3 -> acceptance lane [declared: type marker, spec line 76]
route: A4 -> acceptance lane [declared: type marker, spec line 78]
route: A5 -> acceptance lane [declared: type marker, spec line 103]
route: A6 -> acceptance lane [declared: type marker, spec line 105]
route: A7 -> acceptance lane [declared: type marker, spec line 107]
route: A8 -> acceptance lane [declared: type marker, spec line 109]
route: A9 -> acceptance lane [declared: type marker, spec line 111]
route: A10 -> acceptance lane [declared: type marker, spec line 135]
route: A11 -> acceptance lane [declared: type marker, spec line 137]
route: A12 -> acceptance lane [declared: type marker, spec line 139]
route: U1 -> unit lane [declared: traces FR-004 → BarrelExports/HideEmission contract rows]
route: U2 -> unit lane [declared: traces FR-005..FR-007 → ZuraffaEnsure contract row]
route: U3 -> unit lane [declared: traces FR-008 → MakeReceipt contract row]
route: U4 -> unit lane [declared: traces FR-010 → BarrelExports contract row]

## Red-evidence protocol

Each `[behavior: *]` task certifies RED before its implementation task
runs GREEN: the failing assertion, the file, and the exact command are
recorded in `tdd/red-evidence.md`; `tdd/verification.md` records the
green evidence and the SC-005 regression sweep.
