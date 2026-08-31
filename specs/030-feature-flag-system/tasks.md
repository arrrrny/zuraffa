# Tasks: Feature-Flag System — enable/disable zuraffa features per build

**Input**: Design documents from `/specs/030-feature-flag-system/`

**Prerequisites**: plan.md, spec.md

**Tests**: MANDATORY (tdd.plan) — the feature IS a config + generation
contract; spec SC-001..SC-004 demand automated proof. Every behavior in
`tdd/test-list.md` has a test task below, and each test must be observed
failing before its implementation task starts. Config/CLI/registry tests
are fast tier; the flavor e2e is an integration test on a real temp
project.

**Organization**: Tasks grouped by user story from spec.md. Behavior
markers (`[A1]`, `[U1]`) trace tasks to `tdd/test-list.md`;
`/speckit.tdd.run` ticks tasks by these markers.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Baseline proof and schema shared by all stories

- [x] T001 Record the pre-feature baseline: `dart analyze` clean and
      `tools/run_tests_chunked.sh` result on the feature branch at start;
      note the `zfa feature` command currently has no list/enable/disable
      and `.zfa.json` has no `features:`/`flavors:` support
- [x] T002 [U1] Write the failing model/parse tests FIRST in
      `test/feature_flags/feature_flag_config_test.dart`: gate syntax
      parse (`membership:pro`, `locale:en-US,en-GB`, `variant:a|b`,
      `custom:heavy`), invalid gate syntax rejection, feature-name syntax
      validation, duplicate-name rejection — observe red

## Phase 2: User Story 1 — Declare and toggle features in config (P1) 🎯 MVP

**Goal**: `features:`/`flavors:` parse + validate; `zfa feature
list/enable/disable` works end-to-end.

**Independent Test**: Add a `features:` block to `.zfa.json`, run
`zfa feature list`, see names + status; `zfa feature disable <name>`
updates the config and the list reflects it.

- [x] T003 [US1] [U1] Implement `lib/src/feature_flags/feature_flag.dart` +
      `lib/src/feature_flags/feature_flag_config.dart`: models, `features:`
      list-of-objects and `flavors:` map parsing (via `ZfaConfig`), strict
      validation (unknown flavor-overridden feature, unknown gate type,
      bad names, duplicates) with errors naming the offender; make T002
      green
- [x] T004 [US1] [U2] Write the failing CLI tests FIRST in
      `test/feature_flags/feature_flag_cli_test.dart` (via `CliRunner` on a
      temp project): `zfa feature list` exits 0 with features + status
      (empty config → empty valid list) [A1][A2]; `zfa feature disable
      beta-scheduler` updates `.zfa.json` and the list reflects it [A3];
      `enable` re-enables; `--format=json` prints JSON — observe red
- [x] T005 [US1] [U2] Implement `lib/src/feature_flags/feature_flag_cli.dart`
      + intercept `list|enable|disable` in
      `lib/src/commands/feature_command.dart` (scaffold dispatch untouched
      for every other token); extend `zfa_config.dart` with
      `features`/`flavors` fields; make T004 green
- [x] T006 [US1] [A4] Add the validation-fail-fast test: a flavor override
      referencing an undeclared feature makes `zfa feature list` (config
      validation surface) exit non-zero naming the unknown feature; extend
      T003's validator to satisfy it (test-first)

## Phase 3: User Story 2 — Code generation respects feature flags (P1)

**Goal**: `zfa build --flavor` produces per-flavor output; disabled
features leave no trace.

**Independent Test**: Two configs (feature X enabled vs disabled), run
`zfa build` for each, diff: disabled build has zero references to X.

- [x] T007 [US2] [U4] Write the failing registry-emitter tests FIRST in
      `test/feature_flags/registry_emitter_test.dart`: emitted Dart source
      declares `FeatureFlags.isEnabled`, `enabledFeatures`, embeds the
      enabled set only, embeds gate configs, disabled features absent from
      output — observe red
- [x] T008 [US2] [U5] Implement `lib/src/feature_flags/registry_emitter.dart`
      (pure config→source emitter); make T007 green
- [x] T009 [US2] [U4] Write the failing make-skip test FIRST in
      `test/feature_flags/make_skip_test.dart`: with `pro-analytics`
      disabled, `zfa make ProAnalytics di` (temp project) writes zero
      files and prints the skip reason; with it enabled, files are written
      [A5][A6] — observe red
- [x] T010 [US2] [U4] Add the disabled-slice hook in
      `lib/src/commands/make_command.dart` (normalized name match → skip
      before planning); make T009 green
- [x] T011 [US2] [U4] Write the failing route-filter tests FIRST: feed
      `RouteBuildStage` a feature-set excluding the feature that owns an
      `@Route` hit (class-name/file-path match) and assert the router emit
      drops it while enabled routes survive — observe red
- [x] T012 [US2] [U4] Extend `lib/src/dda/plugins/route/route_build_stage.dart`
      with the optional feature-set filter; make T011 green
- [x] T013 [US2] [U3] [A7][A8] Write the failing build-flavor e2e FIRST in
      `test/feature_flags/build_flavor_filter_test.dart` (real temp
      project): `zfa build --flavor free` emits a registry containing only
      the free feature-set and a router without disabled routes;
      `--flavor pro` emits the full set; unknown flavor exits non-zero
      naming it — observe red
- [x] T014 [US2] [U3] Extend `lib/src/commands/build_command.dart` with
      `--flavor <name>`: load config, validate (fail fast naming unknown
      flavor/feature), resolve the flavor feature-set, run the route stage
      with the filter, emit `lib/src/core/feature_flags.g.dart`; make T013
      green

## Phase 4: User Story 3 — Runtime feature registry (P1)

**Goal**: The generated `FeatureFlags` registry answers `isEnabled` /
`enabledFeatures` per build.

- [x] T005b [US3] [A9][A10][A11][A12] (covered by T007/T008 emitter tests +
      T013 e2e): assert emitted registry returns `true`/`false` per
      build-time state, `enabledFeatures` lists exactly the enabled set,
      and unknown names resolve `false` — no duplicate test; credit tasks

## Phase 5: User Story 4/5/6 — Gates and pluggable providers (P2/P3)

**Goal**: membership/locale/variant/custom gates resolve at runtime;
`FeatureFlagProvider` is pluggable with fail-safe fallback.

- [x] T015 [US4] [U6] Write the failing runtime tests FIRST in
      `test/feature_flags/runtime_provider_test.dart`: membership gate —
      tier `free` → disabled, tier `pro` → enabled [A13][A14]; locale
      gate — `fr-FR` → disabled, `en-US` → enabled [A15][A16]; both gates
      — all must pass [A17] — observe red
- [x] T016 [US4/5/6] [U6][U7][U8][U9][U10] Implement
      `lib/src/feature_flags/runtime/feature_flag_provider.dart`:
      `FeatureContext` (tier, locale, variant resolver), gate evaluation
      (all gates must pass), `FeatureFlagProvider` interface,
      `StaticFeatureFlagProvider`, `FailSafeFeatureFlagProvider`
      (provider throws → build-time default [A23]); make T015 green
- [x] T017 [US5] [U8] [A18][A19][A20] Variant selection: variant gate with
      resolver returning `a` activates variant `a`; feature without a
      variant gate has a single default variant; emitter declares both
      variants — extend T007/T015 tests test-first, then green
- [x] T018 [US6] [U9] [A21][A22] Custom provider swap: registered
      `FeatureFlagProvider` overrides build-time defaults; absence of a
      custom provider uses static defaults — extend T015 tests test-first,
      then green

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Delivery gates

- [x] T019 Run `dart analyze` (zero issues) and the scoped fast suite
      (`dart test test/feature_flags/`), fix anything this feature broke
- [x] T020 Run `tools/run_tests_chunked.sh` (whole fast suite, disk-safe)
      — report ACTUAL pass/fail counts
- [x] T021 Run `dart format .` and confirm `git diff --stat` shows zero
      formatting diffs
- [x] T022 Run `/speckit.tdd.verify` and commit `tdd/verification.md` from
      THIS session's real evidence; clean up scratch fixtures and check
      `df -h .`

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: T001 baseline first; T002 (red) gates everything
- **US1 (Phase 2)**: T003 (green for T002) → T004 (red) → T005 (green) →
  T006 — config + CLI foundation BLOCKS all story work
- **US2 (Phase 3)**: T007/T008 (emitter) → T009/T010 (make skip) →
  T011/T012 (route filter) → T013/T014 (flavor e2e)
- **US3 (Phase 4)**: credited through T007/T008/T013 — no separate code
- **US4-6 (Phase 5)**: after T008 (emitter embeds gate configs); T016
  unblocks T017/T018
- **Polish (Phase 6)**: last

### Parallel Opportunities

- T007/T009/T011 test-writing can proceed in parallel once T003 lands
- T015 (runtime gates) is independent of Phase 3 e2e work

## Implementation Strategy

- MVP-first: Phase 1+2 deliver the config+CLI foundation (US1 complete)
- Each test task: RED evidence → implement → GREEN evidence, appended to
  `tdd/cycle-log.md`
- Honest stops: if a hook point proves wrong mid-implementation, stop the
  cycle, record the deviation in the log, adjust plan/tasks
