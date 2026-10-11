# Bug Assessment: `zfa tdd init` writes lib/app.dart importing zuraffa_flutter/get_it but never declares those dependencies

- **Slug**: zfa-tdd-init-missing-flutter-app-deps
- **Created**: 2026-09-09
- **Source**: GitHub issue #1349 (from-scratch zfa TDD guideline walkthrough, todo app, macOS, Flutter 3.47.2 / Dart 3.13.2)
- **Verdict**: valid
- **Severity**: high

## Symptom

On a fresh Flutter project, `zfa tdd init` completes and prints
`Run flutter test to confirm a green baseline`, but the baseline it just
created does not compile:

```
Error: Couldn't resolve the package 'zuraffa_flutter' in 'package:zuraffa_flutter/zuraffa_flutter.dart'.
lib/app.dart:25:9: Error: Type 'GetIt' not found.
```

The generated `lib/app.dart` (day-zero app module, issue #626 contract)
imports `package:zuraffa_flutter/zuraffa_flutter.dart` and exposes
`final GetIt di = GetIt.instance`, while `pubspec.yaml` declares neither
`zuraffa_flutter` nor `get_it`. Every test fails to compile — the
day-zero baseline is red out of the box.

## Root cause

`lib/src/plugins/tdd/commands/init_command.dart` — the Flutter branch of
`_run()`:

1. writes the day-zero app module via `AppModuleWriter(isFlutter: true)`
   (whose rendered source imports the `zuraffa_flutter` barrel and uses
   `GetIt`), and
2. delegates dependency self-healing exclusively to
   `PubspecDevDependenciesPatcher`, which only patches the TESTING
   `dev_dependencies` (`flutter_test`, `test`, `build_runner`,
   `json_serializable`, `coverage`, `mutation_test`).

The runtime dependencies the generated module requires are never
declared. The `--skin` opt-in (`PubspecSkinDependencyPatcher`,
issue #1260) proves the `dependencies:` self-heal pattern exists — it is
simply never applied to the app module's own imports.

## Why the deps must be RUNTIME (`dependencies:`), not dev

`lib/app.dart` is `lib/` source — the real app boots through the
generated container. `zuraffa_flutter` and `get_it` are imported by
runtime code, so they belong under `dependencies:`. Putting them under
`dev_dependencies` would compile the tests while leaving the app
unbuildable (`flutter build` strips dev deps).

## Remediation (pinned)

In the Flutter branch of `zfa tdd init`, run a second self-heal pass
that ensures `zuraffa_flutter` and `get_it` are present under
`dependencies:` — same textual-patching discipline as the existing
patchers (YAML parsed read-only for detection; comments and formatting
preserved; idempotent; hand-edited pubspecs never rewritten when
complete; empty inline `dependencies: {}` expanded; non-empty inline
mappings refused loudly).

Constraints honored:

- fix confined to `init_command.dart` (Flutter branch self-heal);
- generated `lib/app.dart` content unchanged;
- `test/bootstrap_smoke_test.dart` content unchanged;
- non-Flutter (pure-Dart) init flow unchanged (a pure-Dart app module
  imports `package:zuraffa`, which the project already declares).

Constraint choices (consistency with the codebase, not new pins):

- `zuraffa_flutter: ^6.0.0` — mirrors `DependencyWirer.standardSet`
  (`lib/src/core/dependencies/dependency_wirer.dart`), the toolchain's
  canonical wiring for this package; latest published 6.2.2 satisfies it.
- `get_it: ^9.2.1` — matches the repo's own resolution pin and the test
  fixtures (`engine_tier_fixture.dart`, `di_setup_execution_test.dart`);
  latest published 9.2.1 satisfies it. Already-declared `get_it` at any
  constraint (e.g. ^8.x) is respected and never touched.

## Tests to add or update

New suite `test/cli/writers/tdd/bug_1349_init_flutter_app_deps_test.dart`
(CliRunner-driven `tdd init --project <tmp fixture>`, mirroring the
bug_1260 test's hermetic pattern):

1. Flutter project: init adds `zuraffa_flutter: ^6.0.0` + `get_it: ^9.2.1`
   under `dependencies:` (and never under `dev_dependencies:`).
2. Flutter project: day-zero surface is self-consistent — `lib/app.dart`
   exists, imports the barrel, and the pubspec declares what it imports.
3. Idempotency: a second run adds nothing twice (each package exactly once).
4. Already-declared deps: pubspec preserved byte-for-byte (with the
   dev_dependencies also complete, isolating the assertion).
5. Pure-Dart project: pubspec untouched by the Flutter app deps
   (non-Flutter flow unchanged — invariant that must stay green pre-fix).
6. Empty inline `dependencies: {}` mapping expanded without duplication.
7. Malformed `dependencies:` value reported as a loud writer failure
   (exit != 0, `writer(s) failed`), not a crash.

## Known verification gap (environment)

This session's sandbox has the Dart SDK (3.13.3) but no Flutter SDK, so
the real-world `flutter test` inside a `flutter create` project was not
executed here. Verification is hermetic: the CliRunner fixtures exercise
the actual `tdd init` code path against real temp project roots, and the
day-zero compile contract is pinned structurally (app.dart exists, its
barrel import is present, the pubspec declares both packages). The gap
is recorded in `tdd/verification.md` (verdict PASS_WITH_GAPS).
