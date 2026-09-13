**Template Version**: `zuraffa-1.0`

# Spec: 1509-toolchain-path-portable

## Overview

Issue #1509: pool task a2679213 hit a toolchain misfire while validating
PR 1491 fixes. The command `/opt/flutter/bin/dart format --set-exit-if-changed ...`
(and the corresponding analyze/test invocations) fails with
`/bin/bash: /opt/flutter/bin/dart: No such file or directory` (exit 127)
in every execution environment that does not provision Flutter at exactly
`/opt/flutter` — CI runners, cloud agent sandboxes, and local dev machines
alike. The project's toolchain knowledge currently encodes one machine's
Flutter install location as a fallback candidate inside the MCP server's
dart locator, which (a) documents a path the execution environment does
not have and (b) invites operators to invoke that literal path directly.
This spec makes the toolchain PATH-RESOLVED everywhere: dart is discovered
from `PATH` first, then from environment-declared locations
(`ZURAFFA_DART_BIN`, `FLUTTER_ROOT`, `ZURAFFA_TOOLCHAIN_HINTS`), so the
project is portable across environments with different Flutter
installations while remaining fully functional in the documented
`/opt/flutter` environment (whose `dart` is on `PATH` and/or declarable
through the new environment hooks — no code change needed there).

Reproduction (issue #1509, exit 127):

```
/opt/flutter/bin/dart format --set-exit-if-changed .
# /bin/bash: /opt/flutter/bin/dart: No such file or directory
/opt/flutter/bin/dart analyze .
# /bin/bash: /opt/flutter/bin/dart: No such file or directory
```

## Acceptance Scenarios

1. **Given** any execution environment where `dart` is on `PATH` (regardless of where the Dart/Flutter SDK physically lives), **When** the project's tooling locates the dart executable, **Then** it uses the `PATH`-resolved `dart` — no tool command, script, template, or source file references `/opt/flutter/bin/dart` as a literal path.
   **Type**: acceptance
2. **Given** an environment where Flutter lives at the documented `/opt/flutter` location, **When** the tooling resolves dart, **Then** it still finds dart — via `PATH` (the documented environment has dart on `PATH` per the issue's own workaround), via `FLUTTER_ROOT` when the Flutter tooling exports it, or via `ZURAFFA_DART_BIN`/`ZURAFFA_TOOLCHAIN_HINTS` when an operator declares the SDK location — so behavior in the documented environment is preserved without any hardcoded path.
   **Type**: acceptance
3. **Given** the repository tree (tracked `*.dart`, `*.sh`, `*.yaml` files), **When** one runs `grep -r '/opt/flutter/bin/dart' --include='*.dart' --include='*.sh' --include='*.yaml' .`, **Then** there are ZERO matches.
   **Type**: acceptance
4. **Given** the MCP server is launched with `ZURAFFA_DART_BIN` pointing at an existing dart executable, **When** the server needs dart (e.g. to resolve the zfa CLI or run pub operations), **Then** that override wins over every discovery tier — operators can pin the toolchain without touching code.
   **Type**: acceptance
5. **Given** an environment with an unusual Flutter install location not covered by `PATH` or `FLUTTER_ROOT` (e.g. a sandbox-mounted SDK), **When** the operator exports `ZURAFFA_TOOLCHAIN_HINTS="<sdk-dir>"`, **Then** the resolver probes `<sdk-dir>/dart` and `<sdk-dir>/bin/dart` among its candidates — unusual locations are declarable through the environment, never through source edits.
   **Type**: acceptance
6. **Given** the pre-change test baseline for this environment (`dart test --preset=all test/plugins/tdd/make_command_test.dart` → 5 pre-existing environment-sensitive failures), **When** the fix lands, **Then** the same suite produces NO NEW failures and the new toolchain resolver suite passes green, with `dart analyze` reporting no new warnings (baseline: 0 errors, 0 warnings, 112 pre-existing infos).
   **Type**: acceptance

## Functional Requirements

- **FR-001**: Every toolchain lookup MUST resolve `dart` from `PATH`
  first (the `which dart` / `where dart` probe), preserving the existing
  resolution order: PATH → dart-next-to-`which flutter` → environment
  roots → remaining candidates. The change is path-DERIVATION, not
  resolution-order.
- **FR-002**: The literal `/opt/flutter/bin/dart` MUST NOT appear in any
  tracked `*.dart`, `*.sh`, or `*.yaml` file. Discovery of unusual SDK
  locations MUST go through environment variables:
  - `ZURAFFA_DART_BIN` — absolute path to the dart executable, probed
    before all other tiers (operator pin);
  - `ZURAFFA_TOOLCHAIN_HINTS` — platform-path-separated list of
    directories, each probed as `<dir>/dart` and `<dir>/bin/dart`
    (declared SDK roots);
  - `FLUTTER_ROOT` — existing behavior, preserved
    (`$FLUTTER_ROOT/bin/dart`).
- **FR-003**: The dart resolution logic MUST live in one shared,
  testable service (`lib/src/utils/dart_toolchain_resolver.dart`) with
  injected dependencies (environment map, PATH probe, filesystem probe)
  so every tier is exercisable in `dart test` without real process
  spawning; the MCP server (`bin/zuraffa_mcp_server.dart`) MUST delegate
  to it and keep its existing cache contract (`_dartProbeDone` /
  `_cachedDartPath`).
- **FR-004**: The PATH probe MUST be platform-correct: `which` on
  POSIX, `where` on Windows (same pattern as
  `test/plugins/helpers/flutter_cluster_fixture.dart`), so the resolver
  is portable to Windows environments too.
- **FR-005**: The neutral, non-machine-specific candidate list MUST be
  derivable as a pure function of the injected environment and home
  directory (`candidatePaths`): every emitted entry MUST be traceable to
  an injected input (`ZURAFFA_TOOLCHAIN_HINTS`, `FLUTTER_ROOT`, home,
  the generic `/usr/local/flutter` hint) — the function MUST carry NO
  constant machine-specific SDK location (the banned
  `/opt/flutter/bin/dart` literal). With an environment that declares no
  SDK locations and no home, the list contains only the neutral generic
  hint. When an environment DECLARES a machine-specific location
  (e.g. `ZURAFFA_TOOLCHAIN_HINTS=/opt/flutter`), deriving entries from
  it is correct and required (see acceptance 2).
- **FR-006**: Existing behavior MUST be preserved for the resolution
  tiers that already work: cached probe (single dart lookup per server
  lifetime), PATH hit returns trimmed stdout, flutter-adjacent dart
  (symlink-resolved sibling), `FLUTTER_ROOT` candidate, HOME-derived
  candidates, and the `/usr/local/flutter` fallback.
- **FR-007**: The fix MUST be scope-limited to toolchain path
  references: no test logic changes, no make-command changes, no state
  machine changes, no changes to documented fixture snapshots.

## Measurable Success Criteria

- **SC-001**: `grep -r '/opt/flutter/bin/dart' --include='*.dart' --include='*.sh' --include='*.yaml' .` returns zero matches (FR-002).
- **SC-002**: `dart analyze .` reports zero errors, zero warnings, and no
  new infos vs. the pre-change baseline of 112 infos (FR-007).
- **SC-003**: `dart test test/utils/dart_toolchain_resolver_test.dart`
  passes fully green (every resolution tier covered).
- **SC-004**: `dart test --preset=all test/plugins/tdd/make_command_test.dart`
  shows no new failures vs. the recorded 5-failure environment baseline
  (FR-007).
- **SC-005**: `dart format --set-exit-if-changed lib test bin` exits 0
  (repo formatting contract, AGENTS.md).
- **SC-006**: In this very sandbox (no Flutter SDK anywhere at a fixed
  path, dart available only on `PATH` at `/home/z/tools/dart-sdk/bin`),
  `dart format`/`dart analyze`/`dart test` all run successfully through
  the PATH-resolved toolchain — the environment class from issue #1509
  now works end to end.

## Out of Scope

- Test logic, `zfa tdd make` command logic, and any state machine —
  untouched (hard constraint).
- The generated fixture snapshot
  `test/fixtures/slice_test_project/.dart_tool/package_config.json`
  (machine-generated pub cache roots such as
  `file:///home/agent/.pub-cache/...` and `file:///opt/flutter/...`):
  slice tests treat unresolvable package roots as external by design
  (U8 of spec 043), so the fixture resolves identically in both
  environment classes; regenerating it would change a test fixture
  snapshot, which the hard constraint forbids. Recorded here so the
  decision is traceable.
- Renaming/relocating the documented `/opt/flutter` environment or
  publishing new operator docs beyond this spec.
