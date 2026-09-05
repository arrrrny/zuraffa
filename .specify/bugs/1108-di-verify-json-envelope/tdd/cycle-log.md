# Cycle Log — bug 1108 (di verify --json envelope)

Append only. Every `red` block below is the evidence that the test existed
and failed before the implementation. All outputs are captured verbatim
from real runs in the 2026-09-05 session; `at:` stamps are reconstructed
from session run order against the tool transcript (the raw captured text
is the load-bearing evidence, not the stamp).

Base commit: 512a8189d07a578117ff0c9d4ff10e34cf105907 (master).
Branch: fix/1108-di-verify-json-envelope.

## Cycle: R0 (red — CLI reproduction, pre-test)

- behavior: the acceptance invocation itself
- kind: red
- classification: usageRefusal (the pre-existing `--json` is a JSON-INPUT
  option from the generic CapabilityCommand; it cannot select JSON output)
- test: n/a (live CLI reproduction in a scratch project with a real
  `dart pub get` + a dangling `getIt.registerFactory<MissingUseCase>` tree)
- command: `dart run bin/zfa.dart di verify Product --json`
- exit: 64
- at: 2026-09-05T07:55:00Z (approx., session step 2)
- output:
```
❌ Missing argument for "--json".
Usage: zfa di verify [arguments]
-h, --help            Print this usage information.
    --json            Pass arguments as JSON string
    --dry-run         Preview changes without executing
    --revert          Revert generated files (delete them)
    --[no-]verbose    Enable verbose logging
```

## Cycle: R1 (red — crash discovery, pre-test)

- behavior: the gate must RUN on a real project at all
- kind: red (pre-existing defect discovered while reproducing; blocks the
  acceptance criterion because a crash emits no envelope)
- classification: runtimeCrash (`Unsupported operation: Cannot change an
  unmodifiable set` — `_PackageResolver.provides` seeded its visited set
  with `const {}` and `_libraryDeclares` memoizes into it; fires on every
  project whose `.dart_tool/package_config.json` resolves a package import)
- command: `dart run bin/zfa.dart di verify Product --verbose` (scratch
  project WITH package_config.json)
- exit: 1
- at: 2026-09-05T07:57:00Z (approx., session step 2)
- output:
```
❌ Error: Unsupported operation: Cannot change an unmodifiable set

Stack trace:
#0      _UnmodifiableSetMixin._throwUnmodifiable (dart:_compact_hash:72:5)
#1      _UnmodifiableSetMixin.add (dart:_compact_hash:76:24)
#2      _PackageResolver._libraryDeclares (package:zuraffa/src/plugins/di/capabilities/verify_capability.dart:447:18)
#3      _PackageResolver.provides (package:zuraffa/src/plugins/di/capabilities/verify_capability.dart:435:11)
#4      DiVerifyCapability._verify (package:zuraffa/src/plugins/di/capabilities/verify_capability.dart:216:29)
```

## Cycle: B1–B4 (red — the new test file, tests before implementation)

- behavior: B1 positive envelope / B2 negative envelope / B3 dead-import
  envelope / B4 text-mode unchanged (run through the then-existing command
  tree via ModularDiCommand, before DiVerifyCommand existed)
- kind: red
- classification: mixed — B1/B2/B3 usageRefusal (package:args rejects the
  valueless `--json` flag through CapabilityCommand), B4 runtimeCrash
  (R1's unmodifiable-set crash through the same path)
- test: test/plugins/di/di_verify_test.dart (group `#1108 di verify --json
  (zuraffa.verdict.v1)`)
- command: `dart test test/plugins/di/di_verify_test.dart`
- exit: 1
- at: 2026-09-05T08:02:00Z (approx., session step RED run)
- output (tail):
```
00:00 +5 -5: Some tests failed.

Failing tests:
  test/plugins/di/di_verify_test.dart: #1108 di verify --json (zuraffa.verdict.v1) negative: --json envelopes the dangling findings with kind/file/member/fix
  test/plugins/di/di_verify_test.dart: #1108 di verify --json (zuraffa.verdict.v1) negative: a dead import lands in findings[].member and details.deadImports
  test/plugins/di/di_verify_test.dart: #1108 di verify --json (zuraffa.verdict.v1) positive: --json emits exactly one envelope line with the exact canonical schema
  test/plugins/di/di_verify_test.dart: #1108 di verify --json (zuraffa.verdict.v1) regression (#1108 red): package-resolved registrations must not crash the resolver — the gate verifies green
  test/plugins/di/di_verify_test.dart: #1108 di verify --json (zuraffa.verdict.v1) text mode (no --json) is unchanged: prose verdict + --> fix: lines, no JSON
```
- note: `+5` = the five pre-existing #974 tests (A2 positive, A2 negative,
  U2, U3, A2 wiring) — all green BEFORE any implementation change; `-5` =
  every new #1108 test red. The R1 crash also surfaced through B4's run
  with the identical `_libraryDeclares` stack.

## Cycle: G1 (green — implementation lands)

- behavior: all of the above
- kind: green
- changes: new `lib/src/commands/di_verify_command.dart` (DiVerifyCommand,
  manual `verify` subcommand, `--json` flag → single-line
  `zuraffa.verdict.v1` envelope; text mode byte-compatible), manual
  registration on ModularDiCommand (manualSubcommandNames #761 hook),
  additive `member` key in the capability's finding JSON, crash fix
  (`const {}` → fresh `<String>{}` per lookup)
- command: `dart test test/plugins/di/di_verify_test.dart`
- exit: 0
- at: 2026-09-05T08:20:00Z (approx., session step GREEN run)
- output:
```
00:00 +11: All tests passed!
```

## Cycle: E2E (green — real CLI, acceptance invocation)

- behavior: the acceptance invocation emits the envelope
- kind: green
- command: `dart run bin/zfa.dart di verify Product --json` (scratch
  project, clean tree)
- exit: 0
- at: 2026-09-05T08:24:00Z (approx.)
- output (positive path, single stdout line):
```
{"schema":"zuraffa.verdict.v1","command":"di verify","verdict":"pass","exit_class":"ok","subject":{"kind":"di","entity":"Product"},"findings":[],"drifts":[],"details":{"danglingClasses":[],"deadImports":[]}}
```
- negative path (dangling tree added): same envelope with `verdict: fail`,
  `exit_class: fail`, two findings with `member: MissingUseCase` /
  `member: MissingRepository`, `details.danglingClasses` populated, exit 1.
- text mode without `--json`: prose verdict with `--> fix:` lines, exit 1
  — unchanged from the pre-fix surface.

## Verification-time re-derivation (red proven against the pre-implementation tree)

- kind: red (re-derived at verification time for git-ordering evidence;
  commit granularity on this branch is combined, stated openly)
- method: the implementation files were removed from the working tree
  (`git stash push -- lib/src/commands/modular_di_command.dart
  lib/src/plugins/di/capabilities/verify_capability.dart` + the untracked
  new file moved aside) while the new test file stayed; the suite ran
  against the pre-implementation lib state; the tree was then restored and
  the suite re-ran green (+11) — restoration verified.
- command: `dart test test/plugins/di/di_verify_test.dart`
- exit: 1
- classification: compileError (the API surface does not exist on the old
  tree)
- at: 2026-09-05T08:47:00Z
- output:
```
  test/plugins/di/di_verify_test.dart:12:8: Error: Error when reading 'lib/src/commands/di_verify_command.dart': No such file or directory
  test/plugins/di/di_verify_test.dart:167:20: Error: Method not found: 'DiVerifyCommand'.
  test/plugins/di/di_verify_test.dart:370:13: Error: 'DiVerifyCommand' isn't a type.
00:00 +0 -1: Some tests failed.
```

## Mutation sampling (deliberate mutants, rubric Q3)

Each mutant was applied, the suite ran, the mutant was reverted, and the
suite re-ran green (+11) — restoration verified per mutant.

- M1: envelope verdict hardcoded to `pass` → CAUGHT (`00:00 +10 -1`;
  `Expected: 'fail' / Actual: 'pass'` — negative envelope test)
- M2: exit code forced to 0 → CAUGHT (`00:00 +8 -3`; the exit-code
  expectations on the negative paths)
- M3: crash fix reverted (`<String>{}` → `const {}`) → CAUGHT
  (`00:00 +10 -1`; `Unsupported operation: Cannot change an unmodifiable
  set` — exactly the R1 failure, killed by the regression test)
- M4: `member` key dropped from the finding JSON → CAUGHT
  (`00:00 +9 -2`; envelope exact-key assertions)

Mutation score: 4/4 caught, 0 survived.
