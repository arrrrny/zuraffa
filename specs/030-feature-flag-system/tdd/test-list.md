---
feature: 030-feature-flag-system
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 23
planned_at: 11de4bfc
updated_at: 11de4bfc
suite_baseline: green
---

# Test List: Feature-Flag System — enable/disable zuraffa features per build

Baseline: `dart analyze` clean at `11de4bfc` (pre-feature HEAD). The list
below re-describes the mechanically seeded ids from `zfa tdd plan` with the
Given-context each acceptance scenario carries in `spec.md`; ids and
criterion traces are unchanged. Verification commands are copied verbatim
from `.specify/memory/tdd-profile.md`.

## Outer loop: acceptance behaviors

One per acceptance scenario in `spec.md` (US1 AC1-4 → A1-A4, US2 AC1-4 →
A5-A8, US3 AC1-4 → A9-A12, US4 AC1-5 → A13-A17, US5 AC1-3 → A18-A20, US6
AC1-3 → A21-A23).

| id  | behavior                                                                                                                                                        | traces  | kind    | state   | test |
| --- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- | ------- | ------- | ---- |
| A1  | Given a project with no `features:` section, when `zfa feature list` runs, it exits 0 and lists no features (empty but valid)                                    | US1.AC1 | example | DONE | `test/feature_flags/feature_flag_cli_test.dart` |
| A2  | Given a config declaring three features (two enabled, one disabled), when `zfa feature list` runs, all three appear with their correct enabled/disabled status   | US1.AC2 | example | DONE | `test/feature_flags/feature_flag_cli_test.dart` |
| A3  | Given an enabled feature `beta-scheduler`, when `zfa feature disable beta-scheduler` runs, `.zfa.json` is updated and the list shows it disabled                 | US1.AC3 | example | DONE | `test/feature_flags/feature_flag_cli_test.dart` |
| A4  | Given a flavor override referencing an undeclared feature, when the config is loaded/validated, validation exits non-zero naming the unknown feature             | US1.AC4 | example | DONE | `test/feature_flags/feature_flag_config_test.dart` |
| A5  | Given feature `pro-analytics` enabled, when `zfa make ProAnalytics di` runs, generated output includes the slice's registrations                                  | US2.AC1 | example | DONE | `test/feature_flags/make_skip_test.dart` |
| A6  | Given the same feature disabled, when `zfa make ProAnalytics di` runs, zero files are written and no reference to `ProAnalytics` appears in generated output      | US2.AC2 | example | DONE | `test/feature_flags/make_skip_test.dart` |
| A7  | Given a flavor-based config, when `zfa build --flavor free` runs only the free feature-set is emitted (registry + routes); `--flavor pro` emits the full set      | US2.AC3 | example | DONE | `test/feature_flags/build_flavor_filter_test.dart` |
| A8  | Given all features enabled, the build output (registry + router) is identical to a build with no `features:` section (which emits no registry)                    | US2.AC4 | example | DONE | `test/feature_flags/build_flavor_filter_test.dart` |
| A9  | Given a build with `pro-analytics` enabled, the generated `FeatureFlags` returns `isEnabled('pro-analytics') == true`                                             | US3.AC1 | example | DONE | `test/feature_flags/registry_emitter_test.dart` |
| A10 | Given a build with `beta-scheduler` disabled, the generated `FeatureFlags` returns `isEnabled('beta-scheduler') == false` and omits it from `enabledFeatures`     | US3.AC2 | example | DONE | `test/feature_flags/registry_emitter_test.dart` |
| A11 | Given a build, `FeatureFlags.enabledFeatures` returns exactly the features enabled for that build                                                                 | US3.AC3 | example | DONE | `test/feature_flags/registry_emitter_test.dart` |
| A12 | Given a query for a feature not declared in config, `FeatureFlags.isEnabled` returns `false` (static registry; no throw)                                          | US3.AC4 | example | DONE | `test/feature_flags/registry_emitter_test.dart` |
| A13 | Given a `membership:pro` gate and user tier `free`, `FeatureFlags.isEnabled` returns `false`                                                                      | US4.AC1 | example | DONE | `test/feature_flags/runtime_provider_test.dart` |
| A14 | Given the same gate and user tier `pro`, `FeatureFlags.isEnabled` returns `true`                                                                                  | US4.AC2 | example | DONE | `test/feature_flags/runtime_provider_test.dart` |
| A15 | Given a `locale:en-US,en-GB` gate and app locale `fr-FR`, `FeatureFlags.isEnabled` returns `false`                                                                | US4.AC3 | example | DONE | `test/feature_flags/runtime_provider_test.dart` |
| A16 | Given the same gate and app locale `en-US`, `FeatureFlags.isEnabled` returns `true`                                                                               | US4.AC4 | example | DONE | `test/feature_flags/runtime_provider_test.dart` |
| A17 | Given both `membership:pro` and `locale:en-US` gates with user `pro` but locale `ja-JP`, the feature is disabled (ALL gates must pass)                            | US4.AC5 | example | DONE | `test/feature_flags/runtime_provider_test.dart` |
| A18 | Given a `variant:a|b` feature, the build-time declaration carries both variants (emitted registry declares the variant list)                                      | US5.AC1 | example | DONE | `test/feature_flags/registry_emitter_test.dart` |
| A19 | Given a variant resolver returning `a`, the runtime resolves variant `a` as active for the feature                                                                | US5.AC2 | example | DONE | `test/feature_flags/runtime_provider_test.dart` |
| A20 | Given a feature without a variant gate, it has a single default variant (no A/B branching)                                                                        | US5.AC3 | example | DONE | `test/feature_flags/runtime_provider_test.dart` |
| A21 | Given a custom `FeatureFlagProvider` is registered, `isEnabled` reflects the provider's values instead of build-time defaults                                     | US6.AC1 | example | DONE | `test/feature_flags/runtime_provider_test.dart` |
| A22 | Given no custom provider is registered, `isEnabled` uses the build-time static default                                                                            | US6.AC2 | example | DONE | `test/feature_flags/runtime_provider_test.dart` |
| A23 | Given a provider that throws, `isEnabled` falls back to the build-time default (fail-safe)                                                                        | US6.AC3 | example | DONE | `test/feature_flags/runtime_provider_test.dart` |

## Inner loop: unit behaviors

### `lib/src/feature_flags/feature_flag.dart` + `feature_flag_config.dart`

| id  | behavior                                                                                                                        | traces      | kind    | state   | test |
| --- | -------------------------------------------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U1  | Parsing accepts the `features:` list-of-objects shape, unique alphanumeric+hyphen names, and the four known gate syntaxes; rejects bad gate syntax, unknown gate types (e.g. `tenant:xyz`), invalid/duplicate names, and flavor overrides pointing at undeclared features — every error names the offender | FR-001 | example | DONE | `test/feature_flags/feature_flag_config_test.dart` |
| U2  | `resolve()` applies a flavor's enabled/disabled overrides over the base declarations and rejects unknown flavor names            | FR-003      | example | DONE | `test/feature_flags/feature_flag_config_test.dart` |

### `lib/src/feature_flags/feature_flag_cli.dart` + `commands/feature_command.dart`

| id  | behavior                                                                                                                        | traces      | kind    | state   | test |
| --- | -------------------------------------------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U3  | `zfa feature list/enable/disable <name>` read+write `.zfa.json` in place (preserving unrelated config keys) and the scaffold dispatch (`zfa feature [mode] <Name>`) keeps working | FR-002 | example | DONE | `test/feature_flags/feature_flag_cli_test.dart` |

### `lib/src/feature_flags/registry_emitter.dart`

| id  | behavior                                                                                                                        | traces      | kind    | state   | test |
| --- | -------------------------------------------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U4  | Emitted source embeds ONLY enabled features/gates (disabled leave no trace) and compiles against the runtime contracts           | FR-004      | example | DONE | `test/feature_flags/registry_emitter_test.dart` |
| U5  | Emitted `FeatureFlags` exposes `isEnabled(name)` (O(1) map) and `enabledFeatures` via DI-able construction                        | FR-005      | example | DONE | `test/feature_flags/registry_emitter_test.dart` |

### `lib/src/commands/make_command.dart` + `lib/src/dda/plugins/route/route_build_stage.dart`

| id  | behavior                                                                                                                        | traces      | kind    | state   | test |
| --- | -------------------------------------------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U6  | A disabled feature's slice (normalized kebab↔Pascal name match) is skipped before planning with a printed reason — zero output   | FR-004      | example | DONE | `test/feature_flags/make_skip_test.dart` |
| U7  | `RouteBuildStage` drops `@Route` hits owned by disabled features (class-name/file-path name segment match) from the router emit  | FR-004      | example | DONE | `test/feature_flags/make_skip_test.dart` |

### `lib/src/feature_flags/runtime/feature_flag_provider.dart`

| id  | behavior                                                                                                                        | traces      | kind    | state   | test |
| --- | -------------------------------------------------------------------------------------------------------------------------------- | ----------- | ------- | ------- | ---- |
| U8  | `membership:<tier>` resolves through the pluggable membership resolver (default local/mock implementation for tests)             | FR-006      | example | DONE | `test/feature_flags/runtime_provider_test.dart` |
| U9  | `locale:<list>` evaluates against the runtime locale (comma-separated allow-list, exact or language-prefix match)                | FR-007      | example | DONE | `test/feature_flags/runtime_provider_test.dart` |
| U10 | `variant:<a|b>` declares both variants and selects at runtime via the pluggable variant resolver; provider throw → static fallback | FR-008, FR-009, FR-010 | example | DONE | `test/feature_flags/runtime_provider_test.dart` |

## Invariants and edge cases still to place

- (placed as U1) Unknown gate type `tenant:xyz` is rejected at validation — spec Edge Case 2.
- (placed as U2) Flavor conflict resolution: last override wins per feature, validated against declared features — spec Edge Case 3.

## Out of scope

- Remote feature-flag services (LaunchDarkly, Firebase Remote Config): spec Assumption 5 — only the pluggable interface is required.
- Stripping already-generated code of a disabled feature's artifacts on rebuild: FR-004 scopes filtering to what generation produces in THIS build; existing hand-written source is untouched.
- Locale case-insensitivity beyond exact/language-prefix match: spec gate syntax fixes `en-US,en-GB` forms.

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md`:

- Single test: `dart test <file> --plain-name "<name>"`
- Whole file: `dart test <file>`
- Full suite (feature scope): `dart test test/feature_flags/`
- Full suite (repo): `tools/run_tests_chunked.sh` (disk-safe chunked runner; never a single `dart test test` on cloud disks)
- Static analysis (full repo): `dart analyze`
