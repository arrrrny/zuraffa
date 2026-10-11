# TDD Test List — Spec 1601 (federated plugin scaffold)

Red pre-fix: B1–B11 all **missing-API red** — `PluginScaffold`,
`PluginFamilyNames`, and the `package plugin` subcommand do not exist yet,
so the behavior files fail to load/compile (B9's CLI invocation exits
non-zero "Unknown command"). No green-by-design guards: this feature adds
an all-new surface; nothing existing is constrained. B9 is the slow tier
(integration tag, network for pub get).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Full-family layout: scaffold `my_plugin` (all platforms) → exactly five package dirs (app, core, android/ios/macos adapters) each with pubspec/analysis_options/README/CHANGELOG/LICENSE/barrel/src/test; monorepo root has README.md, PUBLISH.md, LICENSE, CHANGELOG.md, .gitignore, scripts/{prepare_for_publish.sh,publish.sh,push_to_master.sh} | FR-001 / FR-011 / SC-1 | test/package_sdk/plugin_scaffold_test.dart |
| B2 | Dependency-graph wiring (yaml-parsed): app deps = zuraffa hosted `^6.x` only; core deps = app only; each adapter deps = app + core; no package depends on an adapter; every package version 1.0.0; in-family constraints `^1.0.0` | FR-004 / SC-1 | test/package_sdk/plugin_scaffold_test.dart |
| B3 | Harness integrity: every generated package's test file imports its own barrel and exercises the public surface through a fake channel (no-op stubs fail) | FR-008 / SC-1 | test/package_sdk/plugin_scaffold_test.dart |
| B4 | Publish metadata: every generated pubspec has non-empty description, homepage, repository, issue_tracker, ≥1 topic, version; every package dir has non-empty LICENSE + CHANGELOG.md (pub.dev hard requirement — live evidence research.md D3) | FR-003 / SC-2 | test/package_sdk/plugin_scaffold_test.dart |
| B5 | Overrides placement: sibling path overrides appear only under `dependency_overrides`; hosted in-family constraints stay in `dependencies`; with `--zuraffa-path`, framework path lands in `dependency_overrides` and `dependencies.zuraffa` stays hosted `^6.x` | FR-006 / FR-013 / SC-2 | test/package_sdk/plugin_scaffold_test.dart |
| B6 | Publish tooling: generated `prepare_for_publish.sh` (run in a temp git-init'ed scaffold) rewrites ALL five packages (incl. core) to the target version, rewrites in-family hosted constraints to `^<version>`, propagates the root CHANGELOG entry, and commits; generated `publish.sh` lists app → core → adapters order | FR-007 / SC-2 | test/package_sdk/plugin_scaffold_test.dart |
| B7 | Platform subset: `--platforms android,ios` yields exactly app/core/android/ios (no macos dir) with B1/B2 invariants intact | FR-005 / US3 | test/package_sdk/plugin_scaffold_test.dart |
| B8 | Selection rejection: empty platforms set and unknown platform names throw PluginScaffoldException whose message names the supported set `android, ios, macos` | FR-005 / FR-010 | test/package_sdk/plugin_scaffold_test.dart |
| B9 | END-TO-END (slow tier): real CLI `zfa package plugin e2e_plugin --output <tmp> --zuraffa-path <repo>` → per package `dart pub get` exit 0, `dart analyze --no-fatal-warnings` exit 0, `dart test` exit 0 — zero manual edits, ≤ 8 min | FR-002 / SC-1 | test/package_sdk/plugin_scaffold_e2e_test.dart |
| B10 | Validation rails: invalid names (`Bad-Name`, `9lives`) → snake_case-rule message; existing target dir → exists-message + tree untouched; bad `--zuraffa-path` → not-a-directory message | FR-010 / US5 | test/package_sdk/plugin_scaffold_test.dart |
| B11 | Dry-run purity: dry-run result enumerates exactly the files a real run writes; temp dir empty after dry-run | FR-009 / US5 | test/package_sdk/plugin_scaffold_test.dart |

## Red protocol

```
dart test test/package_sdk/plugin_scaffold_test.dart
dart test test/package_sdk/plugin_family_names_test.dart
# slow tier (needs network + AOT/source runner):
dart test test/package_sdk/plugin_scaffold_e2e_test.dart --tags slow
```
