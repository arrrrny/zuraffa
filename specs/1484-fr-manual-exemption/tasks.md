# Tasks: FR manual exemption (issue #1484)

**Feature**: `specs/1484-fr-manual-exemption/` | **Input**: `spec.md` + `plan.md`

Tests are MANDATORY for every behavior task (red-green-refactor per `/speckit.tdd.plan`). Tasks are dependency-ordered; [P] = parallelizable.

## Phase 1 — Parser: FR routing facts (foundation)

- [x] T001 Add `FrRouting` model + `SpecParser.parseFrRoutings(specMd)` in `lib/src/plugins/tdd/services/spec_parser.dart`: walk FR blocks (fenced blocks blanked, `_frLine` bullet+table, `_endsFrBlock` boundaries, first-wins for `traces:` and `**Type**: manual`), document-wide unit ids. [behavior: U1]
- [x] T002 RED→GREEN: unit tests for `parseFrRoutings` — explicit marker, defaulted (no marker no binding), traced, marker+trace contradiction (marker wins), fenced-block marker ignored, FR-table grammar, unit-id alignment (`spec_parser_fr_manual_1484_test.dart`). [behavior: U1, U2, U3]
- [x] T003 Change `_extractUnit` to route manual FRs (marker OR unbound) to no row while consuming the unit id; traced FRs unchanged. [behavior: U2, U3]

## Phase 2 — Coverage gate + traceability (accounting)

- [x] T004 Extend `CoverageGate.evaluate` with optional `manualFrIds`; manual FR statements count covered, never gaps. [behavior: U4]
- [x] T005 Extend `TraceabilityMatrix.render` with FR manual declarations: main-table `manual` status, `## manual:` section (full text + tag), machine-block `manual:`/`fr-manual:` counts. [behavior: U5]
- [x] T006 RED→GREEN: gate + matrix tests (manual FR covered; matrix section/table/machine-block shapes; acceptance-side `(manual:)` accounting unchanged). [behavior: U4, U5]

## Phase 3 — Plan command (wiring + warning)

- [x] T007 Wire plan: pass `manualFrIds` to the gate; emit the defaulted-FR warning naming the FR + both remedies (guidance only, exit 0); pass FR manual declarations to the matrix render. [behavior: U6, U7]
- [x] T008 Update remaining gate callers for coherence: `ingest_command.dart`, `spec_mutator.dart` (`validateSpecContract`) pass the manual set. [behavior: U4]
- [x] T009 RED→GREEN: end-to-end plan tests via `CliRunner` — manual FR produces no U row + exit 0 + warning text; `traceability.md` manual section rendered; explicitly-marked FR warns nothing. [behavior: U6, U7]
- [x] T010 Backwards-compat proof: plan an all-FR-traced fixture — unit rows byte-identical to pre-1484 derivation (ids, traces cell, state column). [behavior: U8]

## Phase 4 — Sweep + verification

- [x] T011 Update existing tests that asserted the old fallback-to-unit default for untraced FRs (fixtures gain `traces:` lines or assertions updated to manual semantics). [behavior: U8]
- [x] T012 `dart analyze` on changed files; `dart test` on the tdd plugin suites; `dart format .` clean; write `tdd/verification.md` (test-first + evidence audit). [behavior: U1–U8]

## Dependencies

- T002 → T001; T003 → T002
- T004, T005 independent of T003 (parallel with Phase 1 after T001)
- T007 → T004 + T005; T008 → T004; T009 → T007; T010 → T003
- T011 → T003 (sweep after the derivation flip); T012 last
