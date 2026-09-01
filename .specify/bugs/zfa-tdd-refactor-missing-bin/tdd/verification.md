---
feature: zfa-tdd-refactor-missing-bin
issue: 689
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: fix branch fix/689-tdd-refactor-missing-bin-zfa-dart, base master 6e383d7e # audited tree
behaviors: 8
proven: 8
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: unmeasured # no mutation pass for this hotfix; hardcoded-string mutant covered by an explicit assertion
mutants_survived: unmeasured
suite: 356 passed, 0 failed (full fast test/plugins/tdd tree incl. refactor_passes 8, pipeline_runner, step_runner, generation_planner, compose); dart analyze: No issues found; live end-to-end RED+GREEN recorded below
---

# TDD Verification: refactor uses the system zfa build instead of a missing bin/zfa.dart (#689)

**Verdict: PASS.** The issue's exact failure — build pass
`dart run bin/zfa.dart build` exiting 255 with misfire-stop on a project
bootstrapped by `zfa setup` — was reproduced live against the pre-fix code,
and the fixed build pass was proven live to resolve the system-installed zfa
the same way `zfa tdd make` resolves its pipeline entrypoint.

## Audit independence disclosure

The same session authored the fix and this report. The RED evidence was
captured by stashing the fix and running the pre-fix tree against the same
fixture; the outputs below are verbatim command results. The GREEN run uses
an AOT-compiled zfa CLI plus a scripted system-installed `zfa` on PATH so the
resolution tier is directly observable (invocation log).

## Root cause → fix traceability

- `RefactorPasses.defaultPassSpecs` pinned
  `RefactorPassSpec('build', 'dart run bin/zfa.dart build')`, but `zfa setup`
  never creates a project-local `bin/zfa.dart` (it installs the system
  `~/.local/bin/zfa`) — the pass failed on every fresh project.
- Fix: extracted PipelineRunner's entrypoint resolution (spec 047 FR-004 /
  U11-U12 — the resolution `zfa tdd make` already uses) into the shared
  `zfa_entrypoint.dart` (`resolveZfaEntrypoint`, `ResolvedZfaEntrypoint`,
  `PipelineResolutionError` re-exported from pipeline_runner so existing
  imports keep working). `RefactorPasses` now resolves the build pass
  command at run() time: explicit passSpecs (tests) win; otherwise
  `override → Platform.script from source → zfa on PATH → dart+script
  fallback`; on resolution failure the static `zfa build` default is used so
  the executor records the concrete misfire. Doc comments in
  refactor_command.dart and refactor_passes.dart updated; the stale
  "does not depend on a globally activated zfa" rationale replaced.
- No behavioral change to `zfa tdd make`: PipelineRunner delegates to the
  same shared resolver with `commandLabel: 'zfa tdd make'`; error type
  (`PipelineResolutionError`) unchanged.

## Live end-to-end reproduction (real CLI, real fixture)

Fixture: pure-Dart package bootstrapped with `zfa tdd init` (TDD baseline +
profile + dev_dependencies), one trivially green test, one spec dir with a
tdd/ subdir. Preflight suite: green (`dart test` → `+1: All tests passed!`).

**RED (pre-fix tree, `git stash`):**

```
$ dart run bin/zfa.dart tdd refactor --project /tmp/bug689-fixture
   pass: build
     command: dart run bin/zfa.dart build
     exit: 255                      <-- the issue's exit code, verbatim
   pass "build" failed — misfire-stop.
refactor: feature=901-bug689 outcome=runner-error applied=0
REFACTOR EXIT: 1
```

**GREEN (fixed tree):** the CLI was compiled to a standalone executable
(`/tmp/zfa-jit/zfa-cli`, so `Platform.script` is not a source `bin/zfa.dart`)
and a scripted system-installed `zfa` was placed on PATH:

```
$ PATH=/tmp/fakebin:$PATH /tmp/zfa-jit/zfa-cli tdd refactor \
    --project /tmp/bug689-fixture
   pass: build
     command: /tmp/fakebin/zfa build        <-- RESOLVED system zfa
     exit: 0
   pass: format
     command: dart format lib/
     exit: 0
   pass: fix
     command: dart fix --apply lib/
     exit: 0
   no actions applied — clean no-op.
refactor: feature=901-bug689 outcome=clean applied=0
REFACTOR EXIT: 0

$ cat /tmp/fakebin/invocations.log
fake system zfa invoked with args: build     <-- PATH entrypoint invoked
```

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| build pass no longer hardcodes `dart run bin/zfa.dart build` | PROVEN | RED captured live (exit 255, misfire-stop) before the fix; static-specs assertion now pins `zfa build` and the absence of the old string |
| default-specs build pass resolves the entrypoint like make | PINNED | fake-executor test asserts the resolved command ends with ` build` and format/fix remain unchanged |
| existing override wins / missing override misfire-stops | PINNED | resolver unit test (`resolveZfaEntrypoint` with real + missing override) |
| make's resolution unchanged by the extraction | PINNED | pipeline_runner_test suite green (only a type assertion existed on the error; messages preserved via commandLabel) |
| pass order/capture/stop contracts unchanged | PINNED | refactor_passes U1-U5 suite green |

## Mutation results

Not run: no mutation pass for this hotfix. Compensating strength: a mutant
restoring the hardcoded command string fails the pinned static-specs
assertion, and the live RED/GREEN pair exercises the real resolution path
end to end (PATH tier proven via the invocation log).

## Acceptance criteria coverage

| Criterion (issue) | Status |
| ----------------- | ------ |
| `zfa tdd refactor` no longer calls `dart run bin/zfa.dart build` | PROVEN — live RED (old) vs GREEN (new) on the same fixture |
| Build pass uses the system-installed zfa, resolved like make/gen/verify | PROVEN — PATH resolution tier demonstrated live; shared resolver extracted from PipelineRunner |
| Refactor exits 0 on a green suite in a fresh project | PROVEN — REFACTOR EXIT: 0, outcome=clean |
| No new suite failures | PROVEN — 356/356 fast TDD-tree tests pass; dart analyze clean |
