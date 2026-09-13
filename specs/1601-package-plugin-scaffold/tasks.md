# Tasks — Spec 1601 federated plugin scaffold (`zfa package plugin`, MVP-first)

**Traces**: behaviors derived in `tdd/test-list.md` (see tdd.plan) → FR-001..FR-013 / SC-1..SC-4.
**Behavior tasks are MANDATORY** — each `[behavior: B*]` task must be driven red→green by the loop before its implementation task may be ticked.

## Phase 1: Setup

- [ ] T001. [P] Implement `PluginFamilyNames` value type in
      `lib/src/package/plugin_family_names.dart`: `app`, `core`
      (`<name>_platform`), `adapter(platform)` (`<name>_<platform>`),
      pascal forms (`ZuraffaFfi…`), and `PackageRole` /
      `PluginPlatform` enums (`PluginPlatform`: android, ios, macos) —
      the shared vocabulary every later task imports. Traces FR-001.

## Phase 2: User Story 1 — one command scaffolds a complete federated monorepo (P1) 🎯 MVP

**Goal**: `zfa package plugin <name>` produces the five-package family;
every package analyzes and tests clean untouched.

**Independent Test**: generate into a temp dir from the engine; assert
file tree, parse pubspecs, run analyze/test per package.

### Tests for User Story 1 (written first, must FAIL)

- [ ] T002. [P] [US1] [behavior: B1] [MANDATORY] Full-family layout test in
      `test/package_sdk/plugin_scaffold_test.dart`: scaffold
      `my_plugin` (all platforms) into a temp dir; assert the five
      package dirs each contain pubspec/analysis_options/README/
      CHANGELOG/LICENSE/barrel/src/test, and the root carries
      README.md, PUBLISH.md, LICENSE, CHANGELOG.md, .gitignore,
      scripts/{prepare_for_publish.sh,publish.sh,push_to_master.sh}.
      Traces FR-001 / FR-011 / SC-1.
- [ ] T003. [P] [US1] [behavior: B2] [MANDATORY] Dependency-graph wiring test (yaml
      parse, `package:yaml`): app → `zuraffa ^<version>` and no in-family
      deps; core → app only; each adapter → app + core; nobody lists an
      adapter as a dependency; in-family constraints `^1.0.0`; all
      versions `1.0.0`. Traces FR-004.
- [ ] T004. [P] [US1] [behavior: B3] [MANDATORY] Harness-integrity test: each generated
      package's test file references its package's public surface and a
      fake channel (grep the generated sources for the fake channel
      import — tests fail if the wiring is broken, FR-008).

### Implementation for User Story 1

- [ ] T005. [US1] Implement `PluginScaffold` in
      `lib/src/package/plugin_scaffold.dart`: build the full
      monorepo file map (all package templates + root docs + scripts)
      from a request; write dirs/files; return `PluginScaffoldResult`.
      Pure templates, no command deps. Traces FR-001 / FR-004 / FR-011.
- [ ] T006. [US1] Add `plugin` subcommand to
      `lib/src/commands/package_command.dart` parsing
      `--platforms/--description/--repo/--output/--zuraffa-path/--dry-run`,
      delegating to `PluginScaffold`, printing per-package ✓ lines +
      next steps per contracts/zfa-package-plugin.md. Traces FR-001.

**Checkpoint**: `dart run bin/zfa.dart package plugin my_plugin` into a
temp dir → five packages, engine tests green.

## Phase 3: User Story 2 — pub.dev-publishable out of the box (P1)

**Goal**: every generated package carries complete publish metadata and
dev-only overrides placement; publish tooling aligns versions.

**Independent Test**: yaml-assert metadata completeness + overrides
section placement on a fresh scaffold; run the shipped publish-prep
script's logic offline (version rewrite) in a temp clone.

### Tests for User Story 2 (written first, must FAIL)

- [ ] T007. [P] [US2] [behavior: B4] [MANDATORY] Publish-metadata test: every generated
      pubspec parses and has non-empty `description`, `homepage`,
      `repository`, `issue_tracker`, ≥1 `topics` entry, `version`, and
      the package dir contains non-empty LICENSE + CHANGELOG.md
      (pub.dev requirement — live dry-run evidence in research.md D3).
      Traces FR-003 / SC-2.
- [ ] T008. [P] [US2] [behavior: B5] [MANDATORY] Overrides-placement test: sibling path
      overrides appear only under `dependency_overrides` (never under
      `dependencies`), and the hosted in-family constraint is present in
      `dependencies`. With `--zuraffa-path`, the framework path lands in
      `dependency_overrides` while `dependencies.zuraffa` stays hosted.
      Traces FR-006 / FR-013.
- [ ] T009. [P] [US2] [behavior: B6] [MANDATORY] Publish-tooling test: generated
      `scripts/prepare_for_publish.sh` rewrites every package (incl.
      `<name>_platform`) to the target version + `^<version>` in-family
      constraints and propagates the root CHANGELOG entry (assert by
      running the generated script against a scaffolded temp monorepo
      git-init'ed in the test); `publish.sh` lists packages in
      app → core → adapters order. Traces FR-007 / SC-2.

### Implementation for User Story 2

- [ ] T010. [US2] Stamp metadata + overrides in the
      `PluginScaffold` templates (pubspec builder shared per role) and
      emit the three publish scripts + PUBLISH.md with all five packages
      listed (fixes the zuraffa_auth `_platform` drift per research.md
      D7). Traces FR-003 / FR-006 / FR-007 / FR-012 / FR-013.

**Checkpoint**: structural publish contract proven offline; real
`dart pub publish --dry-run` exercised at delivery on zuraffa_ffi.

## Phase 4: User Story 3 — platform selection with correct wiring (P2)

**Goal**: `--platforms` subsets generate exactly app + core + selected
adapters; empty/unknown selections are rejected.

**Independent Test**: scaffold with `{android,ios}`; assert exactly four
packages and clean checks; assert rejections for `''` and `dos`.

### Tests for User Story 3 (written first, must FAIL)

- [ ] T011. [P] [US3] [behavior: B7] [MANDATORY] Subset test: `--platforms android,ios`
      yields exactly app/core/android/ios (no macos dir), same clean
      invariants as the full family. Traces FR-005.
- [ ] T012. [P] [US3] [behavior: B8] [MANDATORY] Selection rejection: empty platforms
      list and unknown platform names throw
      `PluginScaffoldException` naming the supported set; dry-run purity
      maintained. Traces FR-005 / FR-010.

### Implementation for User Story 3

- [ ] T013. [US3] Platform selection in `PluginScaffold` +
      `package plugin` arg parsing (csv parse, validation, error copy).
      Traces FR-005.

## Phase 5: User Story 4 — first consumer: zuraffa_ffi (P2)

**Goal**: the command itself produces the issue-#678 repo; family
verified end-to-end by the real CLI.

**Independent Test**: e2e — CLI scaffold `zuraffa_ffi` in a temp dir →
per-package pub get + analyze + test green.

### Tests for User Story 4 (written first, must FAIL)

- [ ] T014. [US4] [behavior: B9] [MANDATORY] E2E in
      `test/package_sdk/plugin_scaffold_e2e_test.dart`
      (`@Tags(['integration','slow'])`, `run_zfa_source` helper): CLI
      `package plugin e2e_plugin --output <tmp> --zuraffa-path <repo>`
      → per package `dart pub get` (exit 0), `dart analyze
      --no-fatal-warnings` (exit 0), `dart test` (exit 0) — zero manual
      edits, ≤ 8 min budget (mirrors package_e2e_test.dart). Traces
      FR-002 / SC-1.
- [ ] T015. [US4] Delivery task (non-test): scaffold the real
      `~/Developer/zuraffa_ffi` via the delivered command
      (`--description "Typed FFI bindings infrastructure for the
      Zuraffa ecosystem: native library loading, lifecycle, and typed
      error plumbing" --repo arrrrny/zuraffa_ffi`), run per-package pub
      get/analyze/test + `dart pub publish --dry-run` per package, git
      init + initial commit, `gh repo create arrrrny/zuraffa_ffi
      --public --source . --push`. Traces SC-4 / US4 acceptance.

## Phase 6: User Story 5 — safe, inspectable operation (P3)

**Goal**: invalid invocations fail with operator-fixable messages and no
filesystem writes; dry-run reports everything it would create.

**Independent Test**: invoke the engine with each invalid input;
assert exception message + zero side effects; dry-run lists files and
creates nothing.

### Tests for User Story 5 (written first, must FAIL)

- [ ] T016. [P] [US5] [behavior: B10] [MANDATORY] Validation test: bad name
      (`Bad-Name`, `9lives`) → snake_case-rule message; existing target
      dir → exists-message and untouched tree; bad `--zuraffa-path` →
      not-a-directory message. Traces FR-010.
- [ ] T017. [P] [US5] [behavior: B11] [MANDATORY] Dry-run purity: result lists every
      file the real run creates (same relative paths, superset
      equality), and the temp dir remains empty afterwards. Traces
      FR-009.

### Implementation for User Story 5

- [ ] T018. [US5] Validation + dry-run in `PluginScaffold` /
      `package plugin` (name regex, target-exists, zuraffa-path check,
      dry-run short-circuit). Traces FR-009 / FR-010.

## Phase 7: Polish & Cross-Cutting

- [ ] T019. [P] CLI_GUIDE.md + README.md: document
      `zfa package plugin` beside `zfa package create` (surface, options,
      generated family, publish flow pointer).
- [ ] T020. `dart format lib test` clean; `dart analyze` clean;
      feature-scoped `dart test test/package_sdk/` green.

## Dependencies & Execution Order

- T001 → all (shared vocabulary).
- US1 (T002–T006) → MVP; T005 before T006 (command delegates to engine).
- US2 (T007–T010) and US3 (T011–T013) and US5 (T016–T018) extend the
  engine — after US1, before delivery.
- US4 T014 (e2e) after engine complete; T015 last (needs everything).
- Polish T019–T020 last.

## Parallel Opportunities

- T001, T002, T003, T004 are independent test files/bodies.
- T007–T009 independent of each other; T011–T012, T016–T017 likewise.

## Implementation Strategy

MVP = US1 (five-package family + command). Then US2/US3/US5 harden the
engine offline. US4 T014 proves the real CLI end-to-end; T015 delivers
issue #678 (zuraffa_ffi repo created and pushed).
