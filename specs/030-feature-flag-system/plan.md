# Implementation Plan: Feature-Flag System — enable/disable zuraffa features per build

**Branch**: `030-feature-flag-system` | **Date**: 2026-09-01 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/030-feature-flag-system/spec.md`
(seed: GitHub issue #372)

## Summary

Add a first-class feature-flag system to zuraffa. A `features:` section in
`.zfa.json` declares named features (`{ name, enabled, gates? }`) and a
`flavors:` section maps named build flavors (free/pro/…) to per-feature
enabled/disabled overrides. `zfa feature list/enable/disable` reads and
toggles the config. `zfa build --flavor <name>` resolves the effective
feature-set for that build: code generation filters the enabled set
(disabled features leave no trace — skipped slices in `zfa make`, excluded
`@Route` entries in the generated router), and a generated
`feature_flags.g.dart` registry (`FeatureFlags.isEnabled(name)`,
`FeatureFlags.enabledFeatures`) is emitted into the target app. Gates
(`membership:<tier>`, `locale:<list>`, `variant:<a|b>`, `custom:<name>`)
are evaluated at runtime against injectable providers; a
`FeatureFlagProvider` interface can replace static resolution entirely and
a fail-safe wrapper falls back to build-time defaults when a provider
throws.

## Technical Context

**Language/Version**: Dart 3.13+ (repo pins `sdk: ^3.11.0`; installed
toolchain Dart 3.13.2 stable). Pure-Dart root package — a Flutter 3.47+
toolchain is NOT required to build, test, or run it; Flutter appears only
as the companion toolchain the generated app projects target.

**Primary Dependencies**: existing internals only — `ZfaConfig`
(`lib/src/config/zfa_config.dart`, the `.zfa.json` loader/saver),
`FeatureCommand` (`lib/src/commands/feature_command.dart`, the `zfa feature`
front door), `MakeCommand` (`lib/src/commands/make_command.dart`), the DDA
`RouteBuildStage` (`lib/src/dda/plugins/route/route_build_stage.dart`,
which compiles `lib/src/routing/zfa_router.g.dart` from `@Route`
annotations — the routes/nav surface), and the `CliRunner`
(`lib/src/cli/cli_runner.dart`) in-process test entry point. No new pub
dependencies.

**Storage**: `.zfa.json` gains two sections: `features` (list of
`{ name, enabled, gates? }`) and `flavors` (map flavor →
`{ featureName: enabled }`). The generated runtime registry lands at
`lib/src/core/feature_flags.g.dart` in the target app.

**Testing**: `dart test` fast tier for units under
`test/feature_flags/`; the flavor/filter e2e uses a real temp project
driven through `CliRunner` (same pattern as `test/plugins/tdd/scenarios/`).
Per repo policy, whole-suite verification uses `tools/run_tests_chunked.sh`
(disk-safe chunked runner), never a single `dart test test`.

**Target Platform**: macOS/Linux CLI (pure Dart).

**Project Type**: config service + CLI command extension + build pipeline
hook + generated runtime registry.

**Performance Goals**: `zfa feature list/enable/disable` completes well
under the SC-002 budget (<2s for 50 features — it is one JSON read/write
plus a table print). `FeatureFlags.isEnabled` is a map lookup (SC-003,
O(1)).

**Constraints**: existing pipelines are extended, not replaced (spec
Assumption 4). `zfa feature <mode> <Name>` scaffolding must keep working
byte-for-byte; only the exact tokens `list`, `enable`, `disable` are
intercepted before mode dispatch. No new layers: feature-flag logic is a
leaf service imported by the existing commands. `dart analyze` and
`dart format` must stay clean. Gate resolution is fail-safe (FR-010).

**Scale/Scope**: ~6 new source files (~700 LOC), ~6 test files (~900 LOC),
surgical edits to `zfa_config.dart`, `feature_command.dart`,
`make_command.dart`, `build_command.dart`, `route_build_stage.dart`.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is the unfilled template — no ratified
gates to enforce. AGENTS.md constraints respected: no new dependencies, no
new layers, test-first, honest stops.

**Post-design re-check**: no violations — pure-Dart leaf module under
`lib/src/feature_flags/` + hooks into four existing files.

## Project Structure

### Documentation (this feature)

```text
specs/030-feature-flag-system/
├── spec.md              # Draft (input — unchanged)
├── plan.md              # This file
├── tasks.md             # Phase 2 output (/speckit.tasks)
└── tdd/
    ├── test-list.md     # /speckit.tdd.plan output (behaviors + traces)
    ├── cycle-log.md     # append-only red/green evidence (/speckit.tdd.run)
    └── verification.md  # cold-context audit (/speckit.tdd.verify)
```

### Source Code (repository root)

```text
lib/src/feature_flags/
├── feature_flag.dart            # NEW — FeatureFlag/FeatureGate models,
│                                #   gate syntax parse + validation
├── feature_flag_config.dart     # NEW — parse features:+flavors: sections,
│                                #   validate (unknown refs, dup names, bad
│                                #   gates), resolve(flavor) → feature-set
├── feature_flag_cli.dart        # NEW — list/enable/disable service
│                                #   (text/json output, config read/write)
├── registry_emitter.dart        # NEW — pure config→Dart-source emitter for
│                                #   the app's feature_flags.g.dart
└── runtime/
    └── feature_flag_provider.dart  # NEW — runtime contracts: FeatureContext,
                                    #   FeatureFlagProvider (pluggable),
                                    #   StaticFeatureFlagProvider,
                                    #   FailSafeFeatureFlagProvider, gate
                                    #   resolvers (membership/locale/variant)

lib/src/config/zfa_config.dart   # EXTEND — features/flavors fields
                                 #   (fromJson/toJson/copyWith)
lib/src/commands/feature_command.dart  # EXTEND — intercept list|enable|disable
lib/src/commands/make_command.dart     # EXTEND — skip generation for a
                                 #   disabled feature's slice (zero output)
lib/src/commands/build_command.dart    # EXTEND — --flavor <name>; validate
                                 #   config; emit registry; pass feature-set
lib/src/dda/plugins/route/route_build_stage.dart  # EXTEND — drop @Route hits
                                 #   belonging to disabled features

test/feature_flags/
├── feature_flag_config_test.dart      # parsing/validation/flavors
├── feature_flag_cli_test.dart         # zfa feature list/enable/disable
├── registry_emitter_test.dart         # emitted registry correctness
├── runtime_provider_test.dart         # gates + fail-safe + provider swap
├── make_skip_test.dart                # disabled slice → zero output
└── build_flavor_filter_test.dart      # zfa build --flavor e2e (temp project)
```

**Structure Decision**: single-project layout (repo default). New leaf
module `lib/src/feature_flags/` owns all new logic; the four existing files
get minimal, clearly-commented hooks. This mirrors how specs 017/018/027
introduced plugin/kernel modules without new layers.

## Key Design Decisions

1. **`zfa feature` command collision (FR-002)** — `zfa feature` already is
   the slice-scaffold generator (`zfa feature [mode] <Name>`, modes =
   closed set). FR-002 demands `zfa feature list|enable|disable <name>`.
   Resolution: `FeatureCommand.run()` intercepts the exact first-rest-token
   ∈ {`list`, `enable`, `disable`} and delegates to the new
   `FeatureFlagCli` service; every other first token keeps the existing
   scaffold dispatch. `list`/`enable`/`disable` become reserved words for
   scaffold names (documented; entity names are PascalCase, so no real
   collision exists).

2. **Feature ↔ code mapping** — the config schema stays exactly
   `{ name, enabled, gates? }` (spec Key Entities). Mapping from a feature
   name to generated artifacts is by normalized name: `pro-analytics` ↔
   `ProAnalytics` (PascalCase slice, entity, and `@Route` class prefix /
   file-path segment). Disabled slice in `zfa make` → skip with a printed
   reason and zero files. Disabled routes in the DDA stage → the `@Route`
   hit whose class name or file path carries the feature's name segment is
   dropped from the router emit (no route definitions, no nav items —
   SC-001).

3. **Static-by-default runtime (FR-005, FR-010)** — the emitted
   `feature_flags.g.dart` hard-codes the per-build feature-set and gate
   configs into a `FeatureFlags` registry (O(1) map lookup, SC-003). Gate
   evaluation consults injectable resolvers (membership/locale/variant)
   registered on the registry; any resolver throwing/unavailable falls back
   to the build-time static enabled state. A `FeatureFlagProvider`
   interface can replace resolution wholesale (US6); failures fall back to
   the static default (fail-safe).

4. **Variant gate (FR-008)** — `variant:a|b` declares both variants at
   build time; the emitted registry exposes `resolveVariant(feature)`
   delegating to the registered variant resolver (default: variant `a`).
   Generation-time code for both variants is the generated app's
   responsibility (both branches emitted by feature scaffolds; runtime
   picks) — the registry is the selection point, which is what US5's
   acceptance scenarios test.

5. **Validation is strict and named (US1.AC4, edge cases)** — unknown
   feature references (flavor overrides pointing at undeclared features),
   duplicate names, invalid name syntax (must be alphanumeric+hyphen),
   unknown gate types (`tenant:xyz`), and unknown flavors on
   `zfa build --flavor` all fail with errors naming the offending item and
   exit non-zero.

## Complexity Tracking

> No constitution violations to justify — table left empty by design.
