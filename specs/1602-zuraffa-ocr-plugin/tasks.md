# Tasks — Spec 1602 `zuraffa_ocr` federated plugin delivery (MVP-first)

**Traces**: behaviors B1–B4 (`tdd/test-list.md`) → FR-001..FR-006 / SC-1..SC-3.
**Behavior tasks are MANDATORY** — each `[behavior: B*]` task must be driven red→green by the loop before its implementation task may be ticked.

## Phase 1: Setup

- [ ] T001. Record the fixed delivery inputs (name, description, repo
      slug, platforms) in `contracts/ocr-delivery.md` — DONE at plan time;
      this task verifies the contract file matches the spec verbatim.

## Phase 2: User Story 1 — one command scaffolds the OCR family (P1) 🎯 MVP

**Goal**: the real CLI produces the five-package `zuraffa_ocr` family with
every OCR stamp verified.

**Independent Test**: fast-tier instance test (real CLI into temp, offline).

### Tests for User Story 1 (written first, must FAIL)

- [ ] T002. [US1] [behavior: B1] [MANDATORY] Instance layout + stamps in
      `test/package_sdk/plugin_ocr_instance_test.dart`: real CLI scaffold
      into temp; five packages; verbatim description, repository/issue
      tracker slugs, `ocr` topic, version 0.1.0, zuraffa `^6.2.2` hosted,
      no `publish_to`, LICENSE + CHANGELOG per package. Traces FR-001 /
      FR-002 / FR-005(structural) / SC-1.
- [ ] T003. [US1] [behavior: B2] [MANDATORY] Wiring + name shapes +
      harness integrity in the same file: dependency invariants (app →
      zuraffa only; core → app; adapters → app + core; nobody → adapter;
      `^0.1.0` in-family); `OcrPort`/`OcrService` present in the app
      barrel exports; `AndroidOcr`/`IosOcr`/`MacosOcr` class prefixes in
      the adapter sources; each harness imports its barrel and defines a
      test double. Traces FR-003 / FR-002(name shapes).

### Implementation for User Story 1

- [ ] T004. [US1] No code change by design (generator frozen): confirm
      B1/B2 green against the delivered generator and record the run in
      `tdd/cycle-log.md`. If either behavior fails, that is a generator
      defect — STOP and report per the repo's roadblock rule.

**Checkpoint**: OCR instance contract pinned offline.

## Phase 3: User Story 2 — the family is healthy out of the box (P1)

**Goal**: the scaffolded OCR family posts the full board.

**Independent Test**: slow-tier e2e (temp family, network).

### Tests for User Story 2 (written first, must FAIL)

- [ ] T005. [US2] [behavior: B3] [MANDATORY] Family board e2e in
      `test/package_sdk/plugin_ocr_e2e_test.dart`
      (`@Tags(['integration','slow'])`): real CLI scaffold → per package
      `dart pub get`, `dart analyze --no-fatal-warnings`, `dart test`,
      `dart pub publish --dry-run` — all exit 0, ≤ 15 min. Traces FR-004 /
      FR-005 / SC-2.

### Implementation for User Story 2

- [ ] T006. [US2] Confirm B3 green; record elapsed + per-gate results in
      `tdd/cycle-log.md`. STOP and report on any gate failure.

## Phase 4: User Story 3 — the repo exists on GitHub (P2)

- [ ] T007. [US3] [behavior: B4] [MANDATORY] Delivery: run the contract
      invocation in `~/Developer` (produces `~/Developer/zuraffa_ocr`),
      run the full board there, `git init -b master`, initial commit,
      `gh repo create arrrrrny/zuraffa_ocr --public --source . --push`,
      verify `gh repo view` + HTTP 200, and confirm the committed
      manifests carry no local paths (FR-006). Record evidence in
      `tdd/cycle-log.md`. Traces FR-006 / SC-3.

## Phase 5: Polish & Cross-Cutting

- [ ] T008. [P] Comment on issue #684 linking the repo + family packages
      and the generating command (after the repo is pushed).
- [ ] T009. `dart format` clean on touched files; feature-scoped
      `dart test test/package_sdk/` green; commit + push the branch.

## Dependencies & Execution Order

- T001 → T002/T003 (red) → T004 (green) → T005 (red) → T006 (green) →
  T007 (delivery) → T008/T009 (polish).

## Parallel Opportunities

- None material — the behaviors share the generated artifact sequence.

## Implementation Strategy

The feature is an instance delivery: pin the contract offline (B1/B2),
prove the board (B3), ship the repo (B4). Any failure against the frozen
generator is a roadblock to report, not a workaround prompt.
