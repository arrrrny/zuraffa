# Bug Issue: zfa tdd run suite baseline ignores --timeout; 10-min default kills the run on large repos

- **Slug**: tdd-run-baseline-timeout
- **Fetched**: 2026-09-05T10:45:09Z
- **Issue**: 1159
- **URL**: https://github.com/arrrrny/zuraffa/issues/1159
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: bug

## Body


`zfa tdd run <feature>` can never complete on this repo: the full-suite baseline that precedes every `make` step is killed by a hardcoded 10-minute deadline, so `tdd make` always refuses with `runner-error`. Reproduced on feature `077-make-engine-preset` (issue #1109 work, spec-whole run).

## Repro

```bash
zfa tdd run 077-make-engine-preset --timeout 25
```

Output:

```
[run] A1 gen -> ok
[run] A1 verify-red -> certified
[run] A1 make -> runner-error
zfa tdd run: step failed — behavior=A1 step=make outcome=runner-error
```

Standalone:

```bash
zfa tdd make A1 --feature 077-make-engine-preset --project ~/Developer/zuraffa
#    suite baseline: dart test
#    baseline exit: -1, failed: 0
# zfa tdd make: the suite baseline did not produce a usable snapshot. Refusing to
# generate without a trustworthy pre-run failure set.
```

## Expected

- `--timeout 25` passed to `zfa tdd run` should apply to every spawned process, including the run-level suite baseline and the make fallback baseline.
- A repo whose fast suite takes >10 min should still be able to produce a baseline (larger deadline, cached snapshot, or scoped/chunked baseline).

## Actual

- Baseline child is SIGKILLed at 10 minutes (`SuiteRunRecord.exitCode = -1`, `timedOut: true`), no `run-baseline.json` is written, `make` refuses, loop stops at the first behavior. Direct `dart test` on the repo takes well over 10 minutes (fast tier), so this reproduces deterministically.

## Root cause (traced)

`lib/src/plugins/tdd/commands/run_driver_core.dart` (~line 406):

```dart
final baselineRecord = await const SingleTestRunner().runSuite(
  suiteTemplate: suiteTemplate,
  workingDirectory: projectRoot,
);  // <-- `timeout` override NOT forwarded
```

`runSuite` defaults to `TddTimeouts.defaultSuite` = 10 min (`lib/src/plugins/tdd/services/tdd_timeout.dart:48`), which the driver's `timeoutOverride` (from `--timeout`) was meant to override (bug #742 contract: "one uniform deadline for every spawned process"). With no parseable cached baseline, `tdd make` then runs its own live suite baseline against the same wall.

## Suggested fix

1. Forward the driver's `timeoutOverride` into `runSuite(...)` for the run-level baseline.
2. Ensure `tdd run` passes `--timeout` through when spawning `tdd make` (verify the make fallback path honors it).
3. Consider a scoped/chunked baseline option for repos whose fast suite exceeds the deadline (cf. `tools/run_tests_chunked.sh`).

## Context

- Discovered during spec-whole for `specs/077-make-engine-preset` (issue #1109); run stopped per the stop-on-roadblock rule. Evidence: `specs/077-make-engine-preset/tdd/cycle-log.md` (ROADBLOCK entry), `tdd/run-state.json` (A1 red, 23 pending).
- Related: #742 (timeout kill semantics), #741 (suite baseline caching).

## Comments

None.
