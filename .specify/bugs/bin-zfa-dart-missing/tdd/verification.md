---
feature: bin-zfa-dart-missing (bug #717)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 928d1c7
behaviors: 5
proven: 4
likely: 1
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 5
criteria_covered: 5
mutation_score: 100 # scope: lib/src/plugins/tdd/services/refactor_passes.dart, 2 deliberate mutants (no mutation tool wired)
mutants_survived: 0
suite: 2527 passed, 0 failed (chunked fast suite, flutter-tagged excluded), ~18m wall
---

# TDD Verification: bug #717 — tdd refactor calls system zfa build

**Verdict: PASS_WITH_GAPS.** Every criterion in the bug record is covered by a
test that runs against the real entrypoint, both deliberate mutants were
killed, and the full fast suite is green (2,527 passed, 0 failed, including
the 203 tests in `test/plugins/tdd/services`). The one gap: the decisive
new execution regression test landed in the same commit as the fix, so its
red is corroborated only post-hoc (deliberate mutant), not by commit-order
history — classified `LIKELY`, not `PROVEN`.

## Test-first evidence

| Behavior (from issue.md + assessment.md)                                                        | Class  | Evidence                                                                                                                                                                          |
| ----------------------------------------------------------------------------------------------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| B1: build pass must never invoke `dart run bin/zfa.dart build` (root cause part 2)              | PROVEN | Pre-existing #689 tests (`U2`, `the default command never names the nonexistent bin/zfa.dart`) observed RED on pristine HEAD `029f678` before the fix; green after. Tests predate the source change in history. |
| B2: build pass resolves and EXECUTES the system `zfa` on PATH (Option B)                         | LIKELY | New execution test added in the same commit as the fix; red recorded post-hoc via deliberate mutant 1 (package tier restored → test fails). End-to-end proof: AOT binary run.       |
| B3: fix scoped to the refactor pass only                                                         | PROVEN | `rg zfaBuildCommand` shows the only consumer is `RefactorPasses.defaultPassSpecs`; diff touches only `refactor_passes.dart`, its test, and CHANGELOG. Shared `StepRunner.resolveEntrypoint` unchanged (gen/make/verify/run unaffected). |
| B4: no user paths hardcoded                                                                      | PROVEN | Diff contains no absolute/home paths; discovery is PATH-based with injectable `environment`; `--zfa-bin` override tier preserved and still covered by its test.                     |
| B5: full suite has no NEW failures                                                                | PROVEN | 2 pre-existing failures at pristine HEAD (same two tests as B1) now green; chunked fast suite 2,527 passed / 0 failed across 63 chunks (+5 folders with only slow/flutter-tagged tests). |

Red reproduction, CLI level (pre-fix source tree `99b4164` = `3de1229~1`,
published as 6.1.0; fresh `zfa setup --dart zik_zak_tdd` fixture; full cycle
setup → tdd init → plan → gen → verify-red → make green, then):

```
$ dart run /tmp/tdd-prefix/bin/zfa.dart tdd refactor A1 --feature=001-app-bootstrap
zfa tdd refactor: applying passes
   pass: build
     command: dart run bin/zfa.dart build
     exit: 255
     changed: (none)
   pass "build" failed — misfire-stop.
refactor: feature=001-app-bootstrap outcome=runner-error applied=0
exit code: 1
```

Matches the issue report verbatim (`exit: 255`, misfire-stop, overall exit 1).

Green reproduction, CLI level (fix compiled via `dart build cli` and installed
as a system binary on PATH — the reporter's `~/.local/bin/zfa` scenario; fresh
`zfa setup --dart zik_zak_fixed` fixture, same cycle to green `make`):

```
$ zfa tdd refactor A1 --feature=001-app-bootstrap
zfa tdd refactor: applying passes
   pass: build
     command: /tmp/tdd-repro/green-bin/zfa build
     exit: 0
   pass: format
     command: dart format lib/
     exit: 0
   pass: fix
     command: dart fix --apply lib/
     exit: 0
refactor: feature=001-app-bootstrap outcome=clean applied=0
exit code: 0
```

The build pass names and runs the system zfa from PATH, not `bin/zfa.dart`.

Diff against tests that already existed: the only pre-existing-test changes
are `dart format` re-indentation of the bug #689 group (6 `expect` lines
moved, all re-added identically; 0 assertions removed, loosened, renamed out
of filters, or skipped; no thresholds touched).

## Findings

| # | Severity | Finding                                                                                                                                                        | Evidence                                                  |
| - | -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------- |
| 1 | MED      | The bug dir has no `tdd/cycle-log.md`: the red phase lives only in this report and session logs, so the loop's self-recorded evidence chain is thinner than the spec-048 feature flow prescribes | `.specify/bugs/bin-zfa-dart-missing/` (no cycle-log artifact) |
| 2 | LOW      | The shared `StepRunner.resolveEntrypoint` still orders the package-config tier before the PATH tier for its other consumers (make/gen/verify/tdd run). Harmless from a compiled binary (package tier resolves null in AOT) but the same shadowing could resurface there in source/test contexts. Out of scope here by the bug's constraint "fix ONLY the refactor pass" | `lib/src/plugins/tdd/services/step_runner.dart:142-151`   |
| 3 | LOW      | Pre-existing `dart format` drift in `examples/mcp_demo/lib/src/mcp/tools.dart` at base HEAD (left untouched to keep the bug PR scoped)                          | `examples/mcp_demo/lib/src/mcp/tools.dart`                 |

## Mutation results

No mutation tool is wired in the profile (per `tdd-profile.md`), so deliberate
mutants were applied to the changed source file, one at a time, each restored
exactly and followed by a green re-run of
`dart test test/plugins/tdd/services/refactor_passes_test.dart` (11 tests):

| Mutant                                                                                      | Behavior | Survived | Judgment                                                                 |
| ------------------------------------------------------------------------------------------- | -------- | -------- | ------------------------------------------------------------------------ |
| M1: restore the package-config tier (`resolvePackageUri: null` — pre-#717 semantics)         | B1, B2   | No       | Caught by the PATH-tier test AND the new #717 execution test; restored, suite green |
| M2: kill resolution entirely (`zfaBuildCommand` always returns bare `'zfa build'`)           | B2, B4   | No       | Caught by the PATH-tier test and the #717 execution test (exact command asserted); restored, suite green |

Coverage: not run (opt-in per profile, corroboration only).

## Traceability

| Criterion (issue #717 / assessment.md)                                        | Tests / evidence                                                                                                                               | End to end |
| ------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- | ---------- |
| refactor must not call `dart run bin/zfa.dart build`                            | `U2` (`isNot(contains('bin/zfa.dart'))`), `the default command never names the nonexistent bin/zfa.dart`                                         | Yes (CLI repro) |
| system zfa on PATH is discovered and preferred                                  | `a zfa on PATH (system install) is preferred over the fallback`; `the build pass executes the system zfa on PATH in a project without bin/zfa.dart` | Yes (AOT binary run) |
| the resolved system zfa is actually executed with `build`                        | `the build pass executes the system zfa on PATH …` (real executor, invocation recorded by the fake binary)                                        | Yes (AOT binary run) |
| `--zfa-bin` override keeps winning                                              | `an explicit --zfa-bin override wins and names the binary`                                                                                        | (unit)     |
| pass registry unchanged (build → format → fix)                                   | `the default pass set is exactly build, format, fix`; `U1`                                                                                        | (unit)     |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- `slow`/`flutter`-tagged tests: excluded by the chunked fast-suite policy; no
  Flutter SDK exists in this verification environment.
- `BuildCommand` (`zfa build`) internals inside the fixture: the pass only
  spawns it; its codegen semantics are separate features.
- Windows/macOS entrypoint behavior: the AOT end-to-end run and shell-script
  fake zfa are Linux-only.
- Full mutation testing: no tool wired; 2 deliberate mutants only, scoped to
  the one changed source file.
- Other refactor passes' stability beyond registry shape (`format`/`fix` are
  unchanged passthroughs of the stock dart tools).
