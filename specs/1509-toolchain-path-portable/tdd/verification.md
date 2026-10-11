# tdd.verify — Spec 1509 toolchain-path-portable

- **Verified**: 2026-09-13, this session, on
  `feat/1509-toolchain-path-portable` (commits 5865a1e, e137373 and the
  verification commit)
- **Toolchain**: Dart 3.13.3 (stable) on linux_x64, provisioned on PATH
  at `/home/z/tools/dart-sdk/bin` — deliberately an issue-#1509
  environment-class sandbox: NO Flutter SDK anywhere, no `/opt` at all,
  dart available only as a PATH-resolved executable. The fix is
  verified in exactly the environment class that motivated the spec.

## Environment baseline (recorded BEFORE any change)

- `dart pub get --no-example` → green (`example/` is a Flutter package;
  plain `dart pub get` fails there in Flutter-less environments —
  pre-existing, out of scope, unchanged by this spec).
- `dart analyze .` → 0 errors, 0 warnings, **112 infos**.
- `dart format --output=none --set-exit-if-changed lib test bin` →
  exit 0.
- `dart test --preset=all test/plugins/tdd/make_command_test.dart` →
  **33 passing / 5 failing**, failures all in spawn-environment-sensitive
  suites (they run real `dart test` subprocesses inside fixture
  sandboxes): spec 052 A10, A11/U17, A15; bug 829 U-829g, U-829h.
  This is the no-regression bar.

## Test-first evidence (red → green)

| id | red evidence (recorded BEFORE the fix) | green evidence |
| -- | -------------------------------------- | -------------- |
| T-1509-pin | `dart test test/utils/dart_toolchain_pin_test.dart` → `[E]` "Found the banned literal in: [bin/zuraffa_mcp_server.dart]" (the pre-fix line 1638 fallback candidate) | passes; scan of tracked `*.dart`/`*.sh`/`*.yaml` sources is clean |
| T-1509-c1..c5, r1..r6, mcp | `dart test test/utils/dart_toolchain_resolver_test.dart` → compile error: `lib/src/utils/dart_toolchain_resolver.dart: No such file or directory` (the library under test did not exist — tests were authored first) | 13/13 pass over injected probes; zero real process spawning in the suite |
| analyze drift fix | During the first green run, test c1 (as first written) contradicted acceptance 2: it banned env-DERIVED `/opt/flutter` entries while acceptance 2 requires the documented environment to derive them via `ZURAFFA_TOOLCHAIN_HINTS`. `/speckit.analyze` disposition: FR-005 reworded (the ban is on constant source literals, not on environment-declared derivation) and test c1 corrected to pin "no SDK constants when the env declares none" | spec.md FR-005, plan Design Decision 5, and the test now agree |

The resolver tests were written and recorded red BEFORE
`lib/src/utils/dart_toolchain_resolver.dart` existed, and the pin test
was recorded red BEFORE `bin/zuraffa_mcp_server.dart` was edited — the
implementation followed the failures, not the other way around.

## Final verification results (all criteria)

- **SC-001** (FR-002): `grep -r '/opt/flutter/bin/dart' --include='*.dart' --include='*.sh' --include='*.yaml' .` → **"No hardcoded paths found"** (zero matches; the pin test itself composes the banned string from fragments so the gate passes repo-wide).
- **SC-002** (FR-007): `dart analyze .` → 0 errors, 0 warnings, **112 infos = exact pre-change baseline** (no new issues). The touched files (`bin/zuraffa_mcp_server.dart`, `lib/src/utils/dart_toolchain_resolver.dart`, `test/utils/dart_toolchain_*`) analyze clean: "No issues found".
- **SC-003**: `dart test test/utils/` → **All tests passed** (118 tests, including the 14 new spec-1509 tests).
- **SC-004**: `dart test --preset=all test/plugins/tdd/make_command_test.dart` → **33 passing / 5 failing — the identical failure set as the pre-change baseline** (spec 052 A10, A11/U17, A15; bug 829 U-829g, U-829h). Zero new failures; no test logic, make-command, or state-machine code touched.
- **SC-005**: `dart format --set-exit-if-changed lib test bin` → **exit 0** (formatter normalized the two new files to repo style).
- **SC-006**: This sandbox IS the issue-#1509 environment class (PATH-only dart, no Flutter SDK, no `/opt`). Every gate above ran here through the PATH-resolved toolchain — `dart format`, `dart analyze`, `dart test` all executed successfully end to end. Additionally, `candidatePaths` with the documented-env declaration (`ZURAFFA_TOOLCHAIN_HINTS=/opt/flutter`) yields the old last-resort candidate declaratively (acceptance 2 test), so the documented `/opt/flutter` environment keeps working — via PATH/FLUTTER_ROOT/declared hints — with no code literal.

## Test-smell rubric (self-audit)

- **Asserts behavior, not implementation**: the pin test asserts the
  observable repo state (source scan); resolver tests assert resolution
  outcomes (which path is returned / null), not internal call counts.
- **Would it catch the bug?**: reverting the fix (re-adding the literal
  candidate) flips T-1509-pin red immediately — verified by the recorded
  red. Deleting the resolver or reordering tiers flips the tier tests.
- **No environment-dependent assertions in unit tests**: all resolver
  tiers run over injected environment/probes; the only filesystem touch
  is the pin test's source scan, which is rooted at `Directory.current`
  (the `dart test` package-root contract).
- **No vacuous composition**: every tier test has both a positive
  (returns X) and, where meaningful, a negative arm (skips a dead pin,
  continues past a dart-less flutter install, returns null when all
  tiers miss).

## Mutation/robustness notes

Full mutation testing was not run for this spec (out of the MVP scope;
the behavior surface is path resolution, covered by 14 targeted tests
plus the spec-pin scan). Robustness evidence instead: the identical
pre/post failure set on the 38-test `make_command_test` regression
suite, which exercises the MCP-adjacent spawn paths (step spawner,
pipeline runner) that consume dart resolution.

## Acceptance-criteria coverage

| Acceptance scenario | Covered by |
| ------------------- | ---------- |
| 1 (PATH-resolved dart, no literal) | T-1509-pin + SC-001 grep gate |
| 2 (documented env still works) | acceptance-2 test + SC-006 (PATH/FLUTTER_ROOT/hints recipes) |
| 3 (SC-001 grep zero matches) | T010 output recorded above |
| 4 (ZURAFFA_DART_BIN pin wins) | T-1509-r1 / r2 |
| 5 (ZURAFFA_TOOLCHAIN_HINTS probing) | T-1509-c4 + acceptance-2 test |
| 6 (no new failures, analyze clean) | SC-002 / SC-004 baseline comparison |
