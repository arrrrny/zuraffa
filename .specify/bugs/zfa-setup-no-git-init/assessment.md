# Bug Assessment: zfa setup leaves project without git init and hardcodes dependency overrides

- **Slug**: zfa-setup-no-git-init
- **Created**: 2026-08-28
- **Source**: https://github.com/arrrrny/zuraffa/issues/528
- **Verdict**: valid, needs reproduction
- **Severity**: medium

## Report (verbatim or summarized)

`zfa setup <name>` bootstraps a new Zuraffa app but has two bootstrap gaps:
1. No git initialization — created project folder is not a git repo, so `git add .` fails.
2. Hardcoded dependency overrides — `analyzer=^13.1.0` / `meta=^1.19.0` (Flutter) and `analyzer=14.1.0` (Dart) are pinned as literal constants in `dependency_wirer.dart` instead of being pulled from the actual `zuraffa_flutter` / `zuraffa` package.

## Symptom

`zfa setup` creates the app and wires dependencies, but the resulting project folder is not a git repository, so the documented next step `cd <app> && git add .` fails with `fatal: not a git repository`. Separately, the analyzer/meta `dependency_overrides` it injects are fixed string constants that can silently drift out of sync with the versions `zuraffa`/`zuraffa_flutter` actually declare.

## Reproduction

1. Run `zfa setup zuraffa_dashboard` (Flutter path, default).
2. Observe the bootstrap completes and prints the "Next steps" block.
3. Run `cd zuraffa_dashboard && git add .`.
4. Observe `fatal: not a git repository (or any of the parent directories): .git`.
5. Separately, inspect `lib/src/core/dependencies/dependency_wirer.dart` and note the override versions are constant literals (`^13.1.0` / `^1.19.0` / `14.1.0`) rather than derived from the `zuraffa_flutter`/`zuraffa` package.

## Suspected Code Paths

- `lib/src/commands/setup_command.dart:313` (`_createApp`) — runs `flutter create` / `dart create` via `Process.run` (lines 373 / 404) but **never invokes `git init`** on the created folder. No git step exists anywhere in `run()` (lines 99-249).
- `lib/src/commands/setup_command.dart:177` (`DependencyWirer.wire`) — delegates override selection to the wirer without any dynamic resolution.
- `lib/src/core/dependencies/dependency_wirer.dart:96-105` — hardcoded `analyzerOverrideVersion = '14.1.0'`, `flutterAnalyzerOverrideVersion = '^13.1.0'`, `flutterMetaOverrideVersion = '^1.19.0'`.
- `lib/src/core/dependencies/dependency_wirer.dart:114` (`standardSet`) — `zuraffa: ^6.0.0` and `zorphy_annotation: ^2.0.0` are also hardcoded literals (lines 119, 128), and the Flutter override block (lines 143-161) returns the constant versions.
- `lib/src/core/dependencies/dependency_wirer.dart:228` (`addOverrideToPubspec`) — writes the (hardcoded) override values verbatim; there is no code path that reads the source package's own `dependency_overrides`.

## Root Cause Hypothesis

Two independent defects, both confirmed by reading the source:

1. **Missing git initialization.** `_createApp` shells out to `flutter create` / `dart create` and treats a zero exit code as success, but neither the command nor `zfa` itself runs `git init`. (Modern `flutter create` no longer guarantees a `git init` in the target, so relying on it was fragile.) The "Next steps" block then instructs `git add .`, which fails. Confidence: **high**.

2. **Overrides/versions are hardcoded.** The Flutter vs Dart divergence is encoded as literal constants in `DependencyWirer` rather than read from the actual `zuraffa_flutter` / `zuraffa` package. When those packages bump their own `dependency_overrides` (e.g., analyzer/meta to satisfy a newer SDK), `zfa setup` keeps injecting the stale values, risking `pub get` resolution failures and an "unclear" Flutter/Dart split because the two code paths are only as correct as the hand-maintained constants. Confidence: **high**.

## Proposed Remediation

**Preferred (git init):** Add an explicit git-initialization step to `SetupCommand.run()` immediately after `_createApp` succeeds (before or after wiring). Implement a `_gitInit({required String projectRoot, required bool dryRun})` helper that:
- skips if a `.git` directory already exists under `projectRoot` (idempotent; safe inside an existing repo),
- runs `git init` (`Process.run('git', ['init'], workingDirectory: projectRoot)`),
- optionally makes an initial commit (`git add -A && git commit -m "Initial commit (zfa setup)"`) so the project starts clean,
- is a no-op under `--dry-run` (print "Would run: git init") and can be disabled with a `--no-git` flag for CI/automation that manages its own VCS.

This makes the documented `git add .` step work and directly satisfies the "port the standard create command to have a proper git initialization" ask.

**Preferred (dynamic overrides):** Replace the hardcoded constants with values resolved from the real package at wiring time. After `pub add zuraffa_flutter` (Flutter) or `zuraffa` (Dart), resolve the installed package's `pubspec.yaml` (via `.dart_tool/package_config.json` → `packageUri`/`rootUri` → read `pubspec.yaml`) and copy its `dependency_overrides` (analyzer, meta, …) plus its own declared dependency versions into the new project. This guarantees the bootstrapped app's overrides always match what `zuraffa_flutter`/`zuraffa` themselves declare — i.e., "dynamically pulled from the current latest zuraffa package." Keep the hardcoded constants only as an offline fallback (with a printed warning) when the package cannot be resolved. The Flutter/Dart separation then becomes a real, data-driven split keyed off the actual package rather than parallel literals.

**Files likely to change:**
- `lib/src/commands/setup_command.dart` — add git-init step + helper; pass resolved overrides through.
- `lib/src/core/dependencies/dependency_wirer.dart` — replace hardcoded version constants with a resolver (e.g., `overridesFromPackage(String packageName)`) and keep constants only as fallback.
- `lib/src/commands/setup_command_test.dart` — assert the created project is a git repo; assert overrides match the source package.
- `lib/src/core/dependencies/dependency_wirer_test.dart` — assert resolved overrides equal the package's declared overrides; assert offline fallback path.

**Tests to add or update:**
- `setup_command_test`: after a (mocked) `flutter create`, the target dir contains `.git`; with `--no-git` it does not; under `--dry-run` no `git` is invoked.
- `dependency_wirer_test`: `standardSet(isFlutter: true).overrides == zuraffa_flutter.publishedOverrides` (read from the package's own pubspec); same for the Dart path vs `zuraffa`.

## Risks & Considerations

- `git init` inside an existing repo or CI checkout could create a nested repo or interfere with the host VCS — mitigate with the "skip if `.git` exists" guard and the `--no-git` opt-out.
- Dynamic override resolution must degrade gracefully offline (fall back to constants + warning) so `zfa setup` never hard-fails without network.
- Copying the package's exact overrides inherits whatever the package pins; if a future `zuraffa_flutter` pins an analyzer the user's Flutter SDK can't satisfy, the failure shifts to the package itself (acceptable — consistent with how the package behaves in any consumer).
- The pure-Dart path currently pins `analyzer 14.1.0` directly while Flutter uses `^13.1.0`; any dynamic resolver must preserve that distinction per platform.

## Open Questions

- Should `zfa setup` make an initial commit automatically, or only `git init` (leaving commit to the user)? [NEEDS CLARIFICATION: auto-commit behavior]
- Is reading the locally resolved package pubspec acceptable, or must the resolver query the latest published version on `pub.dev`? [NEEDS CLARIFICATION: resolve-from-local-vs-pub.dev]
