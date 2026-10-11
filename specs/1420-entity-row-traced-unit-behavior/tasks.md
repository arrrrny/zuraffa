# Tasks: SPEC 1420 — entity pipeline engages at gen for row-only entity traces

**Feature ID:** 1420-entity-row-traced-unit-behavior
**Issue:** #1420

Dependency-ordered (MVP-first). T1–T4 are the behavioral MVP; T5–T6 are the
accuracy remedy; T7–T9 are non-behavioral. Every behavior has its failing test
written FIRST (see `tdd/test-list.md` — the TDD extension ordering contract).

- [x] T1 (RED→GREEN, SC-3) `declared_routing.dart`: add `declaredRoutingFor`
      returning the full `RoutingDecision?`; make `declaredSignatureFor`
      delegate to it (legacy result pinned byte-identical by
      U-1420-D2/D3).
- [x] T2 (RED→GREEN, SC-1a) `gen_command.dart`: resolve the full decision at
      the #1259 seam; synthesize `<Entity>() -> <Entity>` for the row-only
      entity class (`surface == entityPipeline && signature == null &&
      entityName != null`); feed `UnitContractShape.ofResolved` — entity
      exists → `isA<Entity>()` test + verbatim subject + entity import +
      `<Entity>() -> <Entity>` provenance header (U-1420-G1).
- [x] T3 (RED→GREEN, SC-1b) same seam, entity MISSING → traced
      `zfa:tdd: vacuous-guard` marker on the paired test, `Object?` subject
      degradation with the declared header preserved, gen-time guard-only
      warning token SILENT (U-1420-G2).
- [x] T4 (RED→GREEN, SC-4) no-regression pins: undeclared behavior keeps the
      bare guard + warning (U-1420-G3); declared-signature contract rows keep
      the typed assertion / marker paths (U-1420-D4, existing suites).
- [x] T5 (RED→GREEN, SC-2) `vacuous_guard.dart`: single-sourced
      `vacuousGuardDeclaredTraceRemedyFor` wording (re-gen remedy + hand step,
      no "no traces" claim) (U-1420-V1).
- [x] T6 (RED→GREEN, SC-2) `run_driver_core.dart`: marker-absent vacuous-green
      stop probes `declaredRoutingFor`; declared-trace rows print the accurate
      message + remedy; `stopped_at=<id>:make` machine contract preserved
      (U-1420-R1, driver tier over the fake zfa).
- [x] T7 (docs) spec/plan/tasks/test-list committed under
      `specs/1420-entity-row-traced-unit-behavior/`.
- [x] T8 (verification) real `tdd.verify`: analyze + targeted suites + format
      gate; record ACTUAL counts in `tdd/verification.md`.
- [x] T9 (delivery) push branch; open the PR closing #1420.
