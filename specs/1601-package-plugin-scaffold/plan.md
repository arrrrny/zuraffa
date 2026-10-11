# Implementation Plan: Federated Plugin Scaffold (`zfa package plugin`)

**Branch**: `1601-package-plugin-scaffold` | **Date**: 2026-09-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/1601-package-plugin-scaffold/spec.md`

## Summary

Add `zfa package plugin <name>` — a sibling of `zfa package create` (spec 025)
that scaffolds a complete federated plugin **monorepo** in one command: the
app-facing package, the shared platform-core package, and one platform adapter
per selected platform (Android/iOS/macOS, all by default), plus root README,
publishing guide, LICENSE, and the zuraffa_auth-style publish scripts. Every
generated package must pass `dart analyze`, `dart test`, and
`dart pub publish --dry-run` with zero manual edits. First consumer: the
`zuraffa_ffi` repo (issue #678).

## Technical Context

**Language/Version**: Dart 3.13 (repo pins `sdk: ^3.11.0`), pure-Dart CLI package

**Primary Dependencies**: `args` (CLI), `path`, `yaml` (pubspec assertions in tests), `test`

**Storage**: N/A — file-tree generator writing into the caller's filesystem

**Testing**: `dart test` (package:test ^1.25.0), per `.specify/memory/tdd-profile.md`;
feature-scoped suite `dart test test/package_sdk/` (plugin scaffold joins the
existing package SDK tests); e2e tier `@Tags(['integration', 'slow'])` via
`test/helpers/run_zfa_source.dart` (network needed for `dart pub get`)

**Target Platform**: CLI (macOS/Linux dev machines; generated packages target
Android/iOS/macOS consumers)

**Project Type**: library/cli

**Performance Goals**: scaffold a full 5-package family in < 5 s (file writes only)

**Constraints**: generated packages must analyze/test/publish-dry-run clean with
zero manual edits; scaffold never overwrites existing content (spec 025 rule)

**Scale/Scope**: 1 new command subcommand, 1 scaffold engine class + templates
(~1.5k LOC with tests), 5 generated packages per full scaffold

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The constitution file is the unfilled spec-kit template (no active project
principles) — no specific gates to enforce. Repo-level hard rules honored:

- `dart format lib test` before every commit (CI gate) — planned into every
  implementation task.
- No legacy one-shot generator use; generation flows through zfa commands —
  this feature IS a zfa command.
- STOP-ON-ROADBLOCK: applies to zfa generation flows consuming the CLI; the
  e2e test honors it by failing loudly on first unexpected output.

**Gate result: PASS** (post-design re-check: PASS — contracts below add no
app-level presentation, no routes, no service locator).

## Project Structure

### Documentation (this feature)

```text
specs/1601-package-plugin-scaffold/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── zfa-package-plugin.md   # CLI contract of the new command
└── tasks.md             # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
lib/src/package/
├── plugin_scaffold.dart        # NEW: PluginScaffold engine + PluginScaffoldException/Result
└── plugin_family_names.dart    # NEW: PluginFamilyNames (name derivation, shared w/ tests)

lib/src/commands/
└── package_command.dart        # EXTEND: `zfa package plugin <name>` subcommand

test/package_sdk/
├── plugin_family_names_test.dart   # unit: name derivation (U1)
├── plugin_scaffold_test.dart       # unit: layout, wiring, validation, dry-run (U2-U9)
└── plugin_scaffold_e2e_test.dart   # e2e: scaffold → pub get → analyze → test (SC-001)
```

**Structure Decision**: mirrors the existing package SDK (spec 025): the
scaffold engine lives in `lib/src/package/` as a pure-Dart class (directly
unit-testable with temp dirs), the `package` command gains a `plugin`
subcommand that parses args and delegates. Generated-output e2e tests live
beside the existing `package_e2e_test.dart` and reuse its runner helper.

## Complexity Tracking

> No constitution violations — table intentionally empty.
