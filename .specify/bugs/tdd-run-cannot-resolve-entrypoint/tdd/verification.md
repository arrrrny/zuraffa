---
bug: 690
slug: tdd-run-cannot-resolve-entrypoint
verdict: PASS
verified_at: fix/690-tdd-run-cannot-resolve-entrypoint (pre-PR)
suite: chunked fast suite all chunks OK / TDD slow tiers 21 + 16 + 278 passed / dart analyze clean
---

# TDD Verification: #690 tdd run resolves system zfa binary without --zfa-bin

## Root cause

`StepRunner.defaultZfaBin()` (lib/src/plugins/tdd/services/step_runner.dart)
resolved the entrypoint only from the running script and the package path:
`Platform.script` basename → sibling `bin/zfa.dart` →
`Isolate.resolvePackageUri` → `Platform.script` as a usable file →
`StateError("cannot resolve the zfa entrypoint (package:zuraffa is not on the
package path); pass --zfa-bin explicitly")`. When zfa is installed as a
system binary (pub-global snapshot or compiled exe) every tier misses or
returns an unusable path: a `zfa tdd run` driver then either hard-stops with
the StateError or spawns the raw snapshot directly (exec-format failure →
`runner-error`, exit 2). `RunCommand` maps the StateError to exit 2 /
`result=runner-error` (run_command.dart catch site), which is the failure the
issue reports. The chain had no system-binary tiers at all — never a PATH
lookup, never `Platform.resolvedExecutable`.

## Remediation

Mirror the fallback #665 introduced for `PipelineRunner._resolveEntrypoint`:

- tier 4 (new): concrete PATH lookup of `zfa` (executable bit verified, no
  shell) — **use the system-installed zfa binary directly**;
- tier 5: `Platform.script` as a usable file (preserved from the old chain,
  now after PATH so a pub-global snapshot no longer hijacks the resolution);
- tier 6 (new): `Platform.resolvedExecutable` when it is not a Dart VM name
  (`dart`, `dartvm`, `dartaotruntime` + `.exe`) — the running binary IS the
  installed zfa;
- the terminal `StateError` is unchanged for genuinely unresolvable inputs.

The chain was extracted into `StepRunner.resolveEntrypoint(...)` over
injected inputs (script, resolvedExecutable, environment, package-URI
resolver) so every tier is unit-testable; `defaultZfaBin()` delegates with
`Platform` values (signature unchanged — `CorpusStepRunner` tear-off intact).

## RED evidence (pre-fix, real repro)

`scripts/repro_690.sh` (kept outside the repo; transcript below) shapes the
pub-global install: jit-snapshot of `bin/zfa.dart`, package checkout deleted,
a `zfa` wrapper on PATH, target project with a one-behavior test list:

```
================ RED RUN (no zfa on PATH, no --zfa-bin) ================
[run] B-001 gen -> runner-error
zfa tdd run: step failed — behavior=B-001 step=gen outcome=runner-error
   spawn failed for /tmp/zfa690/zfa.jit: Permission denied
run: feature=090-repro result=runner-error pending=1 red=0 green=0 done=0 stopped_at=B-001:gen
RED-EXIT=2
```

With the wrapper ON PATH the identical failure persisted (pre-fix), proving
no system-binary tier existed:

```
================ GREEN RUN (zfa wrapper on PATH) ================   [pre-fix]
   spawn failed for /tmp/zfa690/zfa.jit: Permission denied
GREEN-EXIT=2
--- spawn.log ---
NO SPAWN LOG
```

Honest note on the failure shape: in this SDK the snapshot file exists, so
the pre-fix chain reaches the usable-file tier and the failure surfaces as
`spawn failed ... Permission denied` (exit 2, `result=runner-error`) rather
than the issue's quoted `StateError` text; the `StateError` is the same
chain's terminal branch (reached when the script path is unusable), asserted
verbatim by the new fast-tier test ("the Dart VM is never returned ...").
Both are the missing-fallback bug; both are fixed by the same tiers.

## GREEN evidence (post-fix, same repro)

```
================ GREEN RUN (zfa wrapper on PATH) ================   [post-fix]
[run] B-001 gen -> ok
[run] B-001 verify-red -> missing-summary
run: feature=090-repro result=stopped pending=1 red=0 green=0 done=0 stopped_at=B-001:verify-red
GREEN-EXIT=1
--- spawn.log ---
WRAPPER-SPAWNED: tdd gen B-001 --feature 090-repro --project /tmp/zfa690/target
WRAPPER-SPAWNED: tdd verify-red B-001 --feature 090-repro --project /tmp/zfa690/target
```

The driver resolved the system-installed `zfa` from PATH with no `--zfa-bin`
and spawned both steps through it (`gen -> ok`; the honest stop afterwards is
the repro wrapper's own contract — it prints no summary line — not an
entrypoint failure).

## Regression tests

`test/plugins/tdd/services/step_runner_test.dart`, group
`bug #690: system-binary entrypoint fallback` (6 tests):

1. resolves the system-installed zfa on PATH (tier 4);
2. final fallback is `Platform.resolvedExecutable` for a compiled binary not
   on PATH (tier 6);
3. a usable `Platform.script` still wins over the resolvedExecutable
   fallback when nothing is on PATH (tier 5 preserved);
4. the Dart VM is never returned as the entrypoint — unresolved input still
   throws the `pass --zfa-bin` StateError;
5. a non-executable PATH candidate is skipped (executable-bit check,
   mirroring #665);
6. `run()` spawns steps through the resolved entrypoint (no `--zfa-bin`).

## Suite

| Suite | Result |
| ----- | ------ |
| `dart analyze` | No issues found |
| `tools/run_tests_chunked.sh` (fast suite, chunked) | OK: all chunks passed |
| `dart test --preset=all test/plugins/tdd/run_command_test.dart` | 21/21 passed |
| `--preset=all` sc_013/sc_014/sc_015/sc_016 (driver scenarios) | 16/16 passed |
| `--preset=all` test/plugins/tdd/services/ + commands/ | 278/278 passed |
| `dart test test/plugins/tdd/services/step_runner_test.dart` | 16/16 (incl. 6 new) |
| `dart format` on changed files | clean |

## Scope disclosure

- The bug assessments for #690 were not present in `.specify/bugs/` on any
  branch of this clone (contrary to the task brief); the remediation was
  taken from the issue text + task brief, which agree.
- The full verify audit (mutation testing, deliberate mutants) was not run —
  this is a bug-fix verification, not a feature audit. Test strength here is
  the injected-input tier matrix plus the end-to-end installed-binary repro.
- `examples/mcp_demo/lib/src/mcp/tools.dart` carries pre-existing format
  drift on pristine master (proven by stashing this branch's changes and
  re-running `dart format --output=none`); left untouched to keep the PR
  scoped. Changed files are format-clean.
