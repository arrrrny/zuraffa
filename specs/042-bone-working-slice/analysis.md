# Cross-Artifact Consistency Analysis — feature 042

**Artifacts**: [spec.md](./spec.md) · [plan.md](./plan.md) · [tasks.md](./tasks.md) · [tdd/test-list.md](./tdd/test-list.md)

## Drift check results

| Check | Result | Notes |
|---|---|---|
| User stories ↔ tasks trace tags | PASS after fix | T012 initially lacked `[US2]` (DI container default comes from `DiChoice`); fixed by tagging `[P] [US2]` alongside US1. |
| FR coverage in tasks | PASS | FR-001→T001/T002/T005/T006; FR-002→T008; FR-003→T009; FR-004→T010/T011; FR-005→T016; FR-006→T012; FR-007→T023/T024; FR-008→T015/T020; FR-009→T018/T019; FR-010→T021; FR-011→T022; FR-012→T013/T014/T017; FR-013→T025; FR-014→T023/T032; FR-015→T026. No orphan FRs. |
| Success criteria ↔ scenario tasks | PASS | SC-001→T030 (structural), SC-002→T027, SC-003→T027, SC-004→T011/T031 (REST datasource + missing-credentials behavior; real-Firebase network call NOT claimed), SC-005→T028, SC-006→T032. |
| Acceptance scenarios ↔ A-series ids | PASS | US1.AC1–4 → A1–A4; US2.AC1–5 → A5–A9; US3.AC1–4 → A10–A13; US4.AC1–5 → A14–A18; US5.AC1–3 → A19–A21; US6.AC1–3 → A22–A24. |
| Edge cases ↔ behaviors | PASS | unsupported type → U3/A-corner covered by U3; duplicate entity → preserved resolver behavior (U-scope, covered by existing resolver tests + T021); auto no-config → U36/A8; digit-prefix slug → U8; flutter_test import → U41/A26; atomic regen → U43/A28; cycle refuse → A18. |
| Plan structure ↔ actual files | PASS | `builders/slice/` layout in plan matches implementation directories; di_choice_resolver.dart location pinned. |
| Seed fidelity (issue #592) | PASS | Every seed bullet traces: bone content list → FR-001..008; DI flag → FR-009; graph-driven inclusion → FR-010; parallel delegation/export → FR-011 + US5; CLI surface → T019–T022; success criteria → SC-001..006. Nothing beyond the seed was added except derived mechanics needed to satisfy "compiles with zero errors" self-containment (Firestore REST choice, plain-Dart tests) — both documented as Assumptions in spec.md. |
| Terminology consistency | PASS after fix | spec said "EntityStubBuilder (rewritten)" — retained class name to minimize churn; plan/tasks consistently say "rewrite" not "replace". Manifest version stays `1` (superset keys) — consistent across spec (FR-007) and plan. |

## Honest scope statements (no drift, recorded for the verifier)

1. **SC-001/SC-002 vs Flutter toolchain**: zuraffa's CI has no Flutter SDK. SC-002 is proven via
   `dart analyze` on the pure-Dart core; the flutter-mode widget files are verified structurally
   (content assertions) and their `flutter analyze` is NOT claimed as executed.
2. **SC-04 real Firebase**: proven that the firebase datasource is generated, wired, and fails
   cleanly without credentials. A live Firestore round-trip is not claimed (no credentials in CI).
3. **Existing 020-era tests** asserting stub emission (`class Product {}`, README placeholders,
   TODO test stubs) are intentionally updated by T026 — the seed issue explicitly calls the old
   output inadequate. Dependency-graph, staleness, and import-scanner behaviors are preserved.

**Verdict**: artifacts aligned; proceed to TDD.
