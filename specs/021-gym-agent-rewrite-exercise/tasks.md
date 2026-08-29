# Tasks: GYM Exercise — Agent Rewrite of a Dart Package Using Only zfa

**Input**: Design documents from `/specs/021-gym-agent-rewrite-exercise/` (spec.md, plan.md)

**Organization**: Tasks grouped by user story. Phase 3 (US1 — compatible rewrite) is the MVP core; US2 (stop-and-report) completes the two-legged protocol; US3/US4 are registration/determinism hardening. The exercise script is the graded test itself (FR-007), so the TDD loop runs against it behavior-by-behavior (`tdd/test-list.md`).

## Phase 1: Setup (Fixtures — FR-003, US4)

- [x] T001 Create `.gym/fixtures/sample-crud-package/pubspec.yaml` — Zuraffa-compatible sample package (`zuraffa` path placeholder `__ZURAFFA_ROOT__`, `zorphy`, `zorphy_annotation`, dev `build_runner`, `publish_to: none`)
- [x] T002 Create `.gym/fixtures/sample-crud-package/lib/legacy_note.dart` + `legacy_tag.dart` — hand-written pre-v5 models (plain Dart, zero imports)
- [x] T003 Create `.gym/fixtures/sample-crud-package/rewrite-manifest.json` — deterministic entity/field/plugin plan for the rewrite
- [x] T004 Create `.gym/fixtures/plain-dart-package/` — non-Zuraffa target (pubspec without zuraffa/zorphy deps + trivial `lib/main.dart`)

## Phase 2: Foundational (Exercise Skeleton — FR-001, FR-006)

- [x] T005 Create `.gym/exercise-agent-rewrite-zfa-only.dart` skeleton: repo-root resolver (`bin/zfa.dart` walker), sandbox lifecycle (wipe + create `.gym/.sandbox/exercise-agent-rewrite-zfa-only/`), `_fail` mis-fire reporting, exit-code grading contract
- [x] T006 Setup phase: copy both fixtures into the sandbox, normalize the `__ZURAFFA_ROOT__` path placeholder to the resolved repo root, `dart pub get` in the compatible target (setup tooling only — FR-008), clear setup-error reporting on failure (edge: no access to deps)
- [x] T007 RED EVIDENCE: run skeleton against unimplemented protocol — capture failing exit (see `tdd/cycle-log.md` cycle 1)

## Phase 3: User Story 1 — Compatible rewrite, zfa-only (P1) 🎯 MVP

- [x] T008 [US1] Compatibility-detection step: run `zfa doctor` in the sandbox target, assert `Zuraffa package found` + `zorphy_annotation found` markers (FR-002) — red first (cycle 2)
- [x] T009 [US1] Rewrite loop from `rewrite-manifest.json`: `zfa entity create -n <Name> --field ...` per entity — red first (cycle 3)
- [x] T010 [US1] Architecture generation: `zfa make <Name> datasource repository usecase` per entity (FR-008: zfa-only) — red first (cycle 3)
- [x] T011 [US1] Compilation proof: `zfa build` (build_runner + embedded `dart analyze`) must report no errors (FR-004) — red first (cycle 4)
- [x] T012 [US1] Verification step: assert canonical v5 layout per entity — `lib/src/domain/entities/<snake>/<snake>.dart` + generated parts, repository, datasources, usecases (FR-004, US1-S3) — red first (cycle 4)
- [x] T013 [US1] GREEN: full compatible leg passes end-to-end

## Phase 4: User Story 2 — Non-compatible: stop-and-report (P1)

- [x] T014 [US2] Detection: `zfa doctor` on the plain fixture, assert `Zuraffa package not found` + `zorphy_annotation not found` markers (FR-002) — red first (cycle 5)
- [x] T015 [US2] Stop-and-report: write structured `NOT-ZURAFFA-COMPATIBLE.md` (package, verdict, why/evidence, what-would-make-it-compatible) — NO rewrite commands invoked (FR-005)
- [x] T016 [US2] No-misfire assertions: target `lib/` stays pristine, no `lib/src/domain/entities/` tree appears; report sections validated — red first (cycle 5)
- [x] T017 [US2] GREEN: stop-and-report leg passes with exit 0 (correct behavior per FR-007/SC-002)

## Phase 5: User Story 3 — Registry integration (P2)

- [x] T018 [US3] Register `agent-rewrite-zfa-only` in `.gym/gym.yaml` (unique id, brief, setup, verifyCommand, evaluate exit-code rule — FR-001)
- [x] T019 [US3] Verify existing `generate-feature` entry is untouched (no regression to zuraffa's existing exercises)

## Phase 6: User Story 4 — Determinism + hardening (P2)

- [x] T020 [US4] Determinism: run the exercise twice in clean sandboxes, assert identical output structure (same file set, US4-S2)
- [x] T021 [US4] Edge handling: setup failure surfaces actionable error (not a misleading grade); agent-tool misuse detection documented (zfa-only enforced by protocol shape)
- [x] T022 [US4] Full-suite regression: `dart analyze` + `dart test` at repo root match master baseline (no `lib/`/`test/` changes)

## Phase 7: SDD closure

- [x] T023 `/speckit.analyze` cross-artifact consistency pass (spec ↔ plan ↔ tasks)
- [x] T024 `/speckit.tdd.verify` audit → `tdd/verification.md` with per-SC verdicts
- [x] T025 Commit artifacts (spec.md, plan.md, tasks.md, tdd/*) + `.gym/` wiring; open PR to master (closes #478)
