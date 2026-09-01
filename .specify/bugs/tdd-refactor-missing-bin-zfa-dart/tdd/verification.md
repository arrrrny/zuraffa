# TDD Verification — tdd-refactor-missing-bin-zfa-dart (#689)

- **Bug**: https://github.com/arrrrny/zuraffa/issues/689
- **Branch**: fix/689-tdd-refactor-missing-bin-zfa-dart
- **Date**: 2026-09-01
- **Verdict**: PASS — the exit-255 misfire is reproduced against master with the real CLI and disappears with entrypoint resolution; the full refactor surface stays green.

## Counts

| Fact | Value |
|------|-------|
| Red-phase proven | Yes — real-CLI E2E on master: build pass exit 255, misfire-stop |
| Green-phase proven | Yes — same E2E on the fix branch exits 0; build pass records the resolved entrypoint |
| New tests | 4 passes-level + 1 command-level (A12) |
| Refactor suites re-run | 24/24 passed (refactor_passes + refactor_command, --preset=all) |
| Mutation gate | not_assessed (mutation_test not configured for this surface; the red/green E2E plus test-level mutants stand in) |

## Root cause

`RefactorPasses.defaultPassSpecs` hardcoded
`RefactorPassSpec(name: 'build', command: 'dart run bin/zfa.dart build')`.
`zfa setup` installs the system zfa (`~/.local/bin/zfa`) and never creates
`bin/zfa.dart` in the project, so the build pass always failed
(`dart: Could not resolve ... bin/zfa.dart` → exit 255) and refactor
misfire-stopped (FR-010) with `outcome=runner-error`. The repo's own test
fixtures masked this by seeding a stub `bin/zfa.dart` into every temp
project — real projects do not have one.

## Fix

- `lib/src/plugins/tdd/services/refactor_passes.dart` — `defaultPassSpecs`
  is now a factory that resolves the build command via `zfaBuildCommand()`
  (new): the same tiers make/gen/verify use through PipelineRunner
  (FR-004 / U11) — `--zfa-bin` override → running CLI from source
  (Platform.script basename `zfa.dart`/`zuraffa.dart`) → system `zfa` on
  PATH (executable candidates only) → dart+script fallback. Paths with
  spaces are quoted; the executor tokenizer is now quote-aware so resolved
  absolute paths execute verbatim.
- `lib/src/plugins/tdd/commands/refactor_command.dart` — new `--zfa-bin`
  option (the same override surface `make` accepts) forwarded to
  `RefactorPasses`; docs updated to stop naming the hardcoded command.

## Red/green evidence (real CLI, no bin/zfa.dart, no --zfa-bin)

Master worktree (ea399d96) — RED, reproducing the issue verbatim:

```
   pass: build
     command: dart run bin/zfa.dart build
     exit: 255
     changed: (none)
   pass "build" failed — misfire-stop.
refactor: feature=001-demo outcome=runner-error applied=0
```

Fix branch — GREEN:

```
[689-e2e] OK: refactor exit=0 (build pass resolved the running CLI entrypoint)
   pass: build
     command: /home/z/tools/dart-sdk/bin/dart /home/z/my-project/zuraffa/bin/zuraffa.dart build
[689-e2e] E2E VERDICT: PASS
```

The build pass invoked the RUNNING CLI (tier 2: Platform.script basename
`zuraffa.dart`) — the same binary the user ran, resolved exactly the way
make/gen/verify resolve it.

## Test-level evidence

| Test | Proves |
|------|--------|
| `an explicit --zfa-bin override wins and names the binary` | tier 1 + evidence records the resolved command |
| `a zfa on PATH (system install) is preferred over the fallback` | tier 3 (executable candidate lookup, injectable PATH) — the issue's `~/.local/bin/zfa` scenario |
| `the default command never names the nonexistent bin/zfa.dart` | the regression itself can never come back |
| U2 updated (`build.command` assertions) | the recorded evidence contract tracks the resolved command |
| A12 `a project without bin/zfa.dart refactors green via --zfa-bin` | end-to-end command behavior on the issue's precondition, asserting the fake zfa actually received the `build` invocation |

## What was not audited

- An AOT-compiled / `dart pub global activate`-installed system zfa was not
  exercised end-to-end (the environment runs the CLI from source); tier 3
  is covered by the injected-PATH unit test, and the resolution logic
  mirrors PipelineRunner's proven implementation.
- The Windows PATHEXT branch of the PATH lookup is untested (Linux-only
  environment).
- The unrelated pre-existing quirk observed while building the E2E
  (day-zero `bootstrap_smoke_test.dart` emitted by `zfa tdd init` imports
  `flutter_test` even when the Dart profile is selected) is out of scope
  for #689 and was worked around in the E2E; it deserves its own report.
- `mutation_test` was not run for this surface (not configured); verdict
  rests on the red/green E2E pair plus the test-level assertions above.
