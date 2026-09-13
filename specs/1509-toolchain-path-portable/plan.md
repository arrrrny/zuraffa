**Template Version**: `zuraffa-1.0`

# Plan: 1509-toolchain-path-portable

## Technical Context

- **Language/stack**: Dart 3.13 (SDK ^3.11.0), pure-Dart root package;
  test runner `dart test` with `dart_test.yaml` presets (`all`,
  regression, integration, ...; default tier excludes `slow`).
- **Issue**: #1509 — `/opt/flutter/bin/dart` unavailable in the execution
  environment (exit 127); toolchain must become PATH-resolved.
- **Existing resolution infrastructure (audited)**:
  - `bin/zuraffa_mcp_server.dart` — `ZuraffaMcpServer._findDartExecutable()`
    (lines ~1605–1646): the ONLY tracked `*.dart/*.sh/*.yaml` file with
    the `/opt/flutter/bin/dart` literal (line 1638, a last-resort
    candidate in the `_findDartExecutable` chain). Chain today:
    1. `which dart` (PATH)
    2. dart next to `which flutter` (symlink-resolved sibling)
    3. `FLUTTER_ROOT/bin/dart`, `$HOME/flutter/bin/dart`,
       `$HOME/development/flutter/bin/dart`, **`/opt/flutter/bin/dart`
       (the defect)**, `/usr/local/flutter/bin/dart`
    Cached via `_dartProbeDone` / `_cachedDartPath`; consumers:
    `_pathWithDart()` (puts dart's dir on child PATH for pub-global
    scripts) and zfa CLI resolution (steps ~1541, 1558).
  - `lib/src/plugins/tdd/services/step_runner.dart` — zfa entrypoint
    resolution (Platform.script → package URI → PATH `zfa` →
    resolvedExecutable); already portable, no dart path literals.
  - `lib/src/plugins/tdd/services/{pipeline_runner,replay_paths,
    refactor_passes,dream_runner}.dart` and
    `lib/src/core/module/post_scaffold_gate.dart`,
    `lib/src/cli/binary_staleness.dart` — use
    `Platform.resolvedExecutable` (the running VM/binary), which is
    inherently environment-portable; no changes needed.
  - `test/plugins/helpers/flutter_cluster_fixture.dart` — precedent for
    FLUTTER_ROOT-first + `which`-fallback resolution and for the
    `Platform.isWindows ? 'where' : 'which'` platform probe.
  - `test/helpers/template_self_hosting.dart` — same FLUTTER_ROOT/PATH
    strategy (comment docs).
  - `lib/src/dda/compiler/ast_scanner.dart` — reads
    `FLUTTER_ROOT` env only (already env-driven).
- **Scripts sweep** (`scripts/*.sh`, `tools/*.sh`, `r.sh`, `r2.sh`,
  `gen_token.sh`): ZERO `/opt/flutter` references — shell scripts invoke
  `dart`/`flutter` bare (PATH-resolved) already. No changes required.
- **Templates sweep** (`.specify/templates/*`, `.specify/extensions/*/`
  templates): ZERO `/opt/flutter` references. No changes required.
- **CI sweep** (`.github/workflows/*`): ZERO `/opt/flutter` references;
  workflows use `dart`/`flutter` from the runner-provided PATH. No
  changes required.
- **Generated artifacts sweep**: only
  `test/fixtures/slice_test_project/.dart_tool/package_config.json`
  carries `file:///opt/flutter/...` roots (plus `/home/agent/.pub-cache`
  roots) — a machine-generated fixture snapshot, out of the verify-grep
  scope (`*.dart/*.sh/*.yaml`), harmless in both environment classes
  because the slice engine treats unresolvable package roots as external
  (spec 043 U8). Explicitly out of scope (hard constraint: fixture/test
  snapshots untouched); documented in spec.md Out of Scope.
- **Docs sweep** (AGENTS.md, CLAUDE.md, README.md, CLI_GUIDE.md, all
  `specs/**`): ZERO `/opt/flutter/bin/dart` references. AGENTS.md already
  documents the correct contract ("run `dart format lib test`",
  "`dart analyze`") — bare, PATH-resolved commands.
- **Baseline recorded in this environment** (dart 3.13.3 on PATH at
  `/home/z/tools/dart-sdk/bin`, no Flutter SDK anywhere):
  - `dart pub get --no-example` → green (example/ is a Flutter package;
    `dart pub get` alone fails there in Flutter-less environments —
    pre-existing, out of scope).
  - `dart analyze .` → 0 errors, 0 warnings, 112 infos.
  - `dart format --output=none --set-exit-if-changed lib test bin` →
    exit 0.
  - `dart test --preset=all test/plugins/tdd/make_command_test.dart` →
    33 passing, 5 failing (spec 052 A10, A11/U17, A15; bug 829 U-829g,
    U-829h) — all spawn-environment-sensitive suites that run real
    `dart test` subprocesses inside fixtures; identical failures
    pre-change, recorded as the no-regression bar.

## Design Decisions

1. **One shared, injectable resolver** (FR-003): new
   `lib/src/utils/dart_toolchain_resolver.dart` exporting
   `DartToolchainResolver` with injected `environment`, `home`, `which`
   (PATH probe), and `fileExists` (filesystem probe), plus the pure
   `candidatePaths({environment, home})` function. Rationale: the MCP
   server's private method is untestable in `dart test` (server class,
   real process spawning); a pure candidate list + injected probes makes
   every tier testable without spawning processes, following the repo's
   established injectable-resolution pattern
   (`StepRunner.resolveEntrypoint` over injected inputs).
2. **Resolution order preserved, derivation env-driven** (FR-001,
   FR-005, FR-006): resolve() = `ZURAFFA_DART_BIN` (new operator pin,
   FR-004) → `which dart` → flutter-adjacent dart → candidatePaths (in
   order: `ZURAFFA_TOOLCHAIN_HINTS`, `FLUTTER_ROOT`, HOME-derived,
   `/usr/local/flutter`). The banned literal is replaced by the
   environment contract: a documented-env operator who needs the old
   last-resort tier exports `ZURAFFA_TOOLCHAIN_HINTS=/opt/flutter` (or
   `ZURAFFA_DART_BIN=/opt/flutter/bin/dart`) — capability preserved,
   hardcoding removed (FR-002).
3. **Delegate, don't duplicate** (FR-003): `ZuraffaMcpServer`
   keeps `_findDartExecutable()` with its exact cache contract and
   return semantics; the body becomes a delegation to a
   `DartToolchainResolver` field. No consumer-facing behavior change
   beyond the resolution gains.
4. **Platform-correct probe** (FR-004): the real `which` adapter uses
   `where` on Windows / `which` elsewhere, mirroring
   `flutter_cluster_fixture.dart`. On POSIX this is behavior-identical.
5. **Spec-pin test** (SC-001): a test reads the tracked source files and
   asserts the banned literal is absent — the test that is RED before
   the fix (proving it guards the regression) and GREEN after. This is
   the recorded red for the TDD cycle, alongside the resolver unit
   tests which are red because the resolver does not exist yet.
6. **No fixture, test-logic, make-command, or state-machine edits**
   (FR-007): the diff is one new library, one rewritten private method
   body, one new test file, and the spec-kit artifacts.

## Risks / Trade-offs

- **Risk**: dropping the `/opt/flutter/bin/dart` last-resort candidate
  could regress environments where dart is NOT on PATH, FLUTTER_ROOT is
  unset, and Flutter lives at /opt/flutter. **Mitigation**: those
  environments are exactly what `ZURAFFA_TOOLCHAIN_HINTS` /
  `ZURAFFA_DART_BIN` are for (declarative, one env var, documented in
  the resolver's dartdoc and this plan); the documented environment per
  the issue body has PATH dart (the workaround proves it).
- **Trade-off**: `/usr/local/flutter/bin/dart` stays as a generic hint.
  It is not machine-specific (no `/opt` literal, not user-derived) and
  removing it would change existing behavior beyond the spec's scope.
