# Tasks: Migrate `html_to_markdown_ffi` to be built on zuraffa

**Input**: Design documents from `/specs/064-migrate-html-to-markdown-ffi/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: TDD is explicitly requested (spec-whole loop). Behavior test tasks carry a
`[behavior: <id>]` marker and are mandatory before their implementation tasks.

**Deliverable**: the monorepo at `~/Developer/html_to_markdown_ffi` (repo `arrrrny/html_to_markdown_ffi`).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelizable (different files, no dependencies)
- **[Story]**: US1–US4 map to spec.md user stories

---

## Phase 1: Setup (Shared Infrastructure)

- [ ] T001 Record the pre-migration baseline in `specs/064-migrate-html-to-markdown-ffi/tdd/cycle-log.md`: `dart pub get` + `dart analyze` + `dart test` in `~/Developer/html_to_markdown_ffi` (clean clone), suite counts + exit codes.
- [ ] T002 [P] Verify the `zfa` CLI is at the 064-era build (`scripts/rebuild.sh` run; `zfa --version` no older than checkout `a1de59d9`).
- [ ] T003 [P] Dry-run proof: `zfa package create-plugin html_to_markdown_ffi --description "…" --no-gate` into a temp dir produces the five-package family with `arrrrny` stamps (no hand edits).

---

## Phase 2: Foundational (Blocking Prerequisites)

**⚠️ CRITICAL**: No user story work begins until the family exists in the real repo.

- [ ] T004 Scaffold the family into `~/Developer/html_to_markdown_ffi` (scaffold into temp, graft `packages/`, `scripts/`, `PUBLISH.md` into the repo; keep git history, root `CHANGELOG.md`, `LICENSE`, README lineage).
- [ ] T005 Move the prebuilt native artifacts from `native/` into the adapters: `packages/html_to_markdown_ffi_android/native/android/{armeabi-v7a,arm64-v8a,x86_64}/…so`, `packages/html_to_markdown_ffi_ios/native/ios/{ios-arm64,ios-sim-arm64,ios-sim-x64}.a`, `packages/html_to_markdown_ffi_macos/native/macos-{arm64,x64}/…dylib`.
- [ ] T006 Stamp migration metadata: pubspec descriptions (HTML→Markdown conversion semantics), version 1.1.0→ family-aligned, topics, repository/issue-tracker `arrrrny/html_to_markdown_ffi` in all five packages.
- [ ] T007 [P] Wire dev-time sibling `dependency_overrides` (app→macos adapter for host proofs; adapters→app+platform) exactly as the scaffold emits; confirm they are publish-stripped.
- [ ] T008 Run the scaffold gate per package: `dart pub get` + `dart analyze` exit 0 in all five packages.

**Checkpoint**: family scaffolded, binaries placed, per-package analysis clean.

---

## Phase 3: User Story 1 — Package compiles and passes its suite as zuraffa-native (P1) 🎯 MVP

**Goal**: `dart pub get` / `dart test` / `dart analyze` green across the family; the app package is a working zuraffa-native package.

**Independent Test**: run the family board (pub get + analyze + test per package) — no failures.

### Tests for User Story 1 ⚠️ FIRST, they must FAIL before implementation

- [ ] T009 [behavior: B1] [US1] Write the in-repo structural proof `~/Developer/zuraffa/test/package_sdk/plugin_html_to_markdown_ffi_instance_test.dart`: family layout, stamps (description/repo/topics/version/hosted zuraffa constraint), dependency graph (nobody→adapter), harness integrity (each package's test imports its barrel). Run it — record RED.
- [ ] T010 [behavior: B2] [US1] Port the legacy test suite (10 files, assertions unchanged, import paths per contracts/public-api.md) into `packages/html_to_markdown_ffi/test/`; add the service-level test `html_to_markdown_ffi_service_test.dart` exercising convert through the service with a fake port. Run — record RED (port/service/fakes do not exist yet).

### Implementation for User Story 1

- [ ] T011 [US1] App package: customize the scaffold's port/service/exception/module to conversion semantics (`HtmlToMarkdownFfiPort.convert/convertSync/isSupported`, `HtmlToMarkdownFfiService` facade + typed `HtmlToMarkdownFfiException`, `registerHtmlToMarkdownFfiDependencies`).
- [ ] T012 [P] [US1] Platform package: envelope retargeted to conversion payloads (decode + typed-error mapping + sync helper), `HtmNativeLibraryResolver` seam.
- [ ] T013 [P] [US1] Adapters (android/ios/macos): port + channel + typed exception + `register…` per scaffold shape; default channel performs real FFI on its host platform only.
- [ ] T014 [US1] App package test doubles: fake `HtmlToMarkdownFfiPort` for service tests; make T009/T010 green (service path green offline; legacy suite may still be red until US3 wires the real FFI path).
- [ ] T015 [US1] Family board pass 1: every package `dart pub get` + `dart analyze --no-fatal-warnings` + `dart test` exit 0 (adapters/platform/service tests offline-green; legacy suite green via the macos adapter on host).

**Checkpoint**: US1 — family compiles, suites green, service contract proven with fakes.

---

## Phase 4: User Story 2 — Canonical zuraffa domain layout, zfa-generated (P1)

**Goal**: `lib/src/domain/` layout with zfa-generated architecture; no hand-written architecture files.

**Independent Test**: inspect `packages/html_to_markdown_ffi/lib/src/domain/**` + commit history shows `zfa entity create` / `zfa make` artifacts.

### Tests for User Story 2 ⚠️

- [ ] T016 [behavior: B3] [US1][US2] Structural test (in the in-repo proof file): app package has `lib/src/domain/entities/<snake>/<snake>.dart` (zorphy-generated pair files), generated repository/datasource/usecase artifacts, and the service delegates to the generated use case (source-level assertion + behavior through the fake port). Run — record RED.

### Implementation for User Story 2

- [ ] T017 [US2] Generate the internal entity via `zfa entity create` (zorphy) in `packages/html_to_markdown_ffi` (internal conversion envelope per data-model.md).
- [ ] T018 [US2] Generate repository + datasource + usecase via `zfa make` for that entity; implement the datasource over the port seam (the FFI wrapper lands in US3); wire the service to delegate to the generated use case.
- [ ] T019 [US2] Boundary mapping: public types ↔ internal entities at the service edge (explicit, unit-tested in the service test).

**Checkpoint**: US2 — canonical layout, generated architecture, service → use case → repository path proven with fakes.

---

## Phase 5: User Story 3 — FFI bindings preserved and integrated into the data layer (P1)

**Goal**: real conversion works on the host through the new stack; binding logic preserved (FR-003), datasource wraps the bridge (FR-004), corpus parity (SC-002).

**Independent Test**: the ported legacy suite — real dylib, real conversion — passes through the service/datasource path.

### Tests for User Story 3 ⚠️

- [ ] T020 [behavior: B4] [US3] Add the host FFI proof to the in-repo file (macos host only, guarded): resolve the macos adapter, drive `convert()` through the service on ≥ 20 representative HTML inputs (headings/tables/lists/links/images/edge cases — reuse the legacy corpus), asserting non-empty well-formed output; plus visitor-bridge pin and error-code pins (1→InvalidInputException, 2→ConversionErrorException). Run — record RED.

### Implementation for User Story 3

- [ ] T021 [US3] Preserve the binding layer: `html_to_markdown_bindings.dart` + `native_library.dart` behavior verbatim in the app package (env→bundled→resolver→cache→cargo→open→process chain; `downloadIfNeeded()`), routing binary discovery through the platform `HtmNativeLibraryResolver`.
- [ ] T022 [P] [US3] macos adapter: real dlopen of the bundled arm64/x64 dylibs + sync FFI convert path (uses the shared visitor vtable plumbing).
- [ ] T023 [P] [US3] android adapter: loader over bundled `.so` (loader-path + process fallbacks preserved); ios adapter: process-symbol loader over the statically linked `.a` — binding logic preserved from `native_library.dart` (no new binding logic, FR-007).
- [ ] T024 [US3] FFI datasource: the generated datasource performs the bridge call (options json → `htm_conversion_options_from_json` → `htm_convert` → result json → `ConversionResult`), reusing `checkLastError()` semantics.
- [ ] T025 [US3] Wire the legacy top-level `convert()` to the service sync path; make T010 (legacy suite) and T020 (FFI proof) green on the macOS host.

**Checkpoint**: US3 — real conversion through the zuraffa stack, corpus parity, visitor + error pins hold.

---

## Phase 6: User Story 4 — Platform guidance (P2)

**Goal**: no new platform bindings outside the family; adapters carry only the pre-existing artifacts (FR-007).

**Independent Test**: structural scan — binaries in adapters match the pre-migration `native/` set exactly; binding source equals the preserved logic.

- [ ] T026 [US4] Extend the in-repo structural proof: adapter `native/` trees enumerate exactly the pre-migration artifacts (names + sizes); no Windows/Linux artifacts introduced; android/ios/macos loaders contain no new FFI signatures beyond the preserved `htm_*` set.
- [ ] T027 [P] [US4] Adapter tests over fake channels prove: success decode, typed error taxonomy, timeout, unwired registration — offline on any host (scaffold harnesses, conversion-customized).

**Checkpoint**: US4 — platform surface exactly as pre-migration, tests host-independent.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [ ] T028 [P] READMEs: root + per-package (family table, platform notes, consumption example with `register…Dependencies`).
- [ ] T029 [P] CHANGELOG: root entry `## 1.2.0` (migration notes); `prepare_for_publish.sh` propagates into packages.
- [ ] T030 [P] `dart doc` clean pass; pubspec homepages (`https://zuraffa.com` per family convention); license files present everywhere.
- [ ] T031 Family board full: per package `dart pub get` + `dart analyze --no-fatal-warnings` + `dart test` + `dart pub publish --dry-run` — all exit 0 (quickstart.md §4).
- [ ] T032 Publish: `./scripts/prepare_for_publish.sh 1.2.0` → `git push origin publish-1.2.0` → `bash scripts/publish.sh` → `bash scripts/push_to_master.sh -f` (issue goal: publish to pub.dev).
- [ ] T033 Record delivery evidence in `tdd/cycle-log.md`; run the audit (`/skill:speckit-tdd-verify`) and remediate until green.

---

## Dependencies & Execution Order

- Phase 1 (T001–T003) → Phase 2 (T004–T008) block everything.
- US1 (T009–T015) before US2 (T016–T019) before US3 (T020–T025): the service contract must exist before the generated stack delegates to it; the generated stack must exist before the FFI datasource fills it.
- US4 (T026–T027) rides on US3's loaders; Polish (T028–T033) last; T032 requires T031 green.
- [P] tasks within a phase are file-independent.

## Implementation Strategy

- MVP = Phases 1–3 (family green with fake-port proofs). US2 adds the generated-domain claim; US3 flips the real-FFI path on; US4 pins the platform surface; Polish ships it.
- The generator is frozen: scaffold-level failures are roadblocks (record, fix upstream), not improvised-around.
