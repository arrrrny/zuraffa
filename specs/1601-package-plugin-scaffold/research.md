# Research: Federated Plugin Scaffold (`zfa package plugin`)

**Feature**: specs/1601-package-plugin-scaffold | **Date**: 2026-09-13

All unknowns resolved against primary evidence: the zuraffa_auth and
zuraffa_permissions checkouts (`~/Developer/`), the existing spec-025
`PackageScaffold` implementation, and a live `dart pub publish --dry-run`
against `zuraffa_auth_platform`.

## D1 — Command shape: `zfa package plugin <name>`

- **Decision**: New subcommand of the existing `package` command:
  `zfa package plugin <name> [options]`.
- **Rationale**: `zfa plugin …` is already taken (codegen plugin
  list/add/enable/disable). `package create` (spec 025) established the
  package SDK family; a plugin is a kind of package family, so it belongs
  under `package`. Keeping `create` untouched avoids breaking spec-025
  consumers.
- **Alternatives considered**: extend `package create --platforms`
  (rejected: overloads a single-package command with monorepo semantics);
  top-level `zfa plugin create` (rejected: collides with existing
  codegen-plugin management).

## D2 — Generated package shape: pure-Dart federated (zuraffa_auth model)

- **Decision**: Adapters and core are **pure Dart** packages: no Flutter
  SDK dependency, platform access through an injected platform-channel
  abstraction (typed envelope in, typed result or typed error out), the
  zuraffa_auth layout. Default platforms: android, ios, macos.
- **Rationale**: Verified against `~/Developer/zuraffa_auth/packages/*` —
  every pubspec resolves only `sdk` deps (`zuraffa`, in-family, `test`,
  `lints`); adapters ship `register.dart` + a channel wrapper, not native
  sources. This shape is fully testable with `package:test` on the dev
  machine (the TDD loop needs no simulator). zuraffa_permissions' Flutter
  style pulls `flutter test` into every package — rejected for the
  generator default.
- **Alternatives considered**: `plugin_platform_interface` federated
  Flutter plugins (rejected for tests + heavier pubspec; can be a future
  `--template flutter` flag, out of scope); shipping native Swift/Kotlin
  stubs (rejected: untestable in pure `dart test`, not needed by the FFI
  consumer).

## D3 — Publish-critical files: per-package LICENSE + CHANGELOG.md

- **Decision**: Every generated package gets its own `LICENSE` (MIT,
  `Copyright (c) 2026 Ahmet TOK`, matching the family) and a seeded
  `CHANGELOG.md` (`## 1.0.0` entry). Root gets LICENSE too.
- **Rationale**: Live `dart pub publish --dry-run` on
  `zuraffa_auth/packages/zuraffa_auth_platform` **fails** with
  `You must have a LICENSE file in the root directory`, and warns about a
  missing `CHANGELOG.md`. The generator must do better than the hand-built
  repo it is modeled on.

## D4 — Local development resolution: `dependency_overrides` (pub strips on publish)

- **Decision**: Adapters/core declare in-family hosted constraints
  (`^1.0.0`) AND a `dependency_overrides` block with sibling `path:`s;
  `prepare_for_publish`-style tooling does not need to strip anything.
- **Rationale**: Verified: pub ignores `dependency_overrides` when
  publishing (zuraffa_auth's `restore_dev_setup.sh` literally documents
  this), and the dry-run above only *hints* about overrides. The
  `--zuraffa-path` option maps the framework dep the same way
  PackageScaffold does (`zuraffa: path: …` inside `dependencies` is NOT
  publishable — so for plugins the path goes into `dependency_overrides`
  instead, keeping `zuraffa: ^6.x` hosted; this is a deliberate divergence
  from spec-025's single-package approach which sets `publish_to: none`).

## D5 — Scaffold engine architecture

- **Decision**: `PluginScaffold` class in `lib/src/package/`
  mirroring `PackageScaffold`: validate (name regex `^[a-z][a-z0-9_]*$`,
  existing target, unknown platform, empty selection, `--zuraffa-path`) →
  build `Map<String, String>` of relative path → content → dry-run
  short-circuit → write dirs + files → `PluginScaffoldResult`.
  Name derivation via `PluginFamilyNames` (pure value type:
  `app`, `core`, `adapter(platform)`, pascal forms).
- **Rationale**: Direct precedent (spec 025) with existing tests to model;
  keeps the command layer thin and the engine unit-testable.
- **Alternatives considered**: string-template files in assets/
  (rejected: PackageScaffold established inline templates; one less
  asset-loading failure mode); reusing PackageScaffold per package then
  patching (rejected: in-family wiring + overrides + root tooling need a
  family-level writer).

## D6 — Versions and constraints

- **Decision**: All packages start at `1.0.0`; in-family constraints
  `^1.0.0`; `zuraffa: ^<repo version>` from `lib/src/version.dart`
  (same source PackageScaffold uses); `environment.sdk: ^3.11.0`;
  `homepage: https://zuraffa.com`; `repository`/
  `issue_tracker` from `--repo` (default `arrrrny/<name>`); topics
  `zuraffa` + role/platform topics.
- **Rationale**: Matches zuraffa_auth pubspecs (v6 line) and keeps
  in-family bumps mechanical (prepare_for_publish rewrites both).

## D7 — Publish tooling shipped into the monorepo

- **Decision**: Generate `scripts/prepare_for_publish.sh` (version-align
  all packages incl. core, propagate root CHANGELOG entry, commit on
  `publish-<version>` branch), `scripts/publish.sh` (dry-run + publish in
  dependency order: app → core → adapters, with pub.dev propagation wait),
  `scripts/push_to_master.sh`, `PUBLISH.md` workflow doc, root `README.md`
  with the family table.
- **Rationale**: verbatim surface of the zuraffa_auth pipeline
  (PUBLISH.md documents the same 5-step flow), with two fixes: **all**
  packages including `<name>_platform` appear in the script lists
  (zuraffa_auth's scripts omit it — drift), and publish order puts the
  app-facing package first exactly as documented.

## D8 — Test strategy for the TDD loop (what proves FR-002/FR-003 in-loop)

- **Decision**:
  - Unit tests (fast, offline): parse every generated pubspec with
    `package:yaml`; assert roles, dependency edges (FR-004), overrides
    placement (FR-006), metadata completeness (description/homepage/
    repository/topics/LICENSE/CHANGELOG → FR-003 structurally), file
    layout (FR-001), validation errors + dry-run purity (FR-009/FR-010),
    platform subset (FR-005).
  - Generated-content compile check: `dart analyze` the scaffold **engine
    test** covers templates by generating into a temp dir and running
    `dart analyze` on ONE package per role (needs `dart pub get` first —
    tagged `slow`, mirrors package_e2e_test.dart's tier).
  - Full e2e (`integration`,`slow`): CLI scaffold → per-package
    `pub get` + `analyze` + `test` (SC-001, ≤ 8 min timeout like the
    existing e2e).
  - Actual `dart pub publish --dry-run` is executed at **delivery time**
    for the real consumer (zuraffa_ffi), not in the loop — it validates
    against the live pub.dev service and would make the suite
    network-mandatory; structural FR-003 assertions + D3's live evidence
    cover the contract in-loop.
- **Alternatives considered**: dry-run inside unit tests (rejected:
  network dependency + minutes-slow); no structural pubspec assertions
  (rejected: dry-run-only feedback is too late and too coarse).

## D9 — Where the FFI consumer fits

- **Decision**: `zuraffa_ffi` is generated by the delivered command with
  `--description "Typed FFI bindings infrastructure for the Zuraffa
  ecosystem: native library loading, lifecycle, and typed error plumbing"`,
  repo `arrrrny/zuraffa_ffi`, then git init + GitHub create + push.
- **Rationale**: Issue #678 says the repo is 404 and "the first step is to
  scaffold it before migrating". FFI domain code (bindings, DynamicLibrary
  policy) is the follow-up migration, not the scaffold.
