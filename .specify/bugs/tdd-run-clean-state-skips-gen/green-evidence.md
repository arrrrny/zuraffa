# Green Evidence — bug 720 (tdd-run-clean-state-skips-gen)

- **Date**: 2026-09-01
- **Branch**: fix/720-tdd-run-clean-state-skips-gen (fix applied to
  `lib/src/plugins/tdd/commands/run_command.dart`)
- **Binary**: real `zfa` recompiled from the fixed `bin/zfa.dart` (Dart 3.13.3)

## Same clean state as the red evidence

Prior interrupted run's residual red evidence retained in
`specs/990-bug720-repro/tdd/cycle-log.md`; `run-state.json`,
`artifacts.json`, `test/tdd/a1_test.dart`, `lib/tdd/a1_subject.dart` all
wiped. No in-flight marker.

## GREEN output (post-fix)

```
$ zfa tdd run 990-bug720-repro --project . --zfa-bin zfa
zfa tdd run: feature 990-bug720-repro — 1 behavior(s)
[run] A1 gen -> ok
[run] A1 verify-red -> certified
[run] A1 make -> green
[run] A1 refactor -> clean
run: feature=990-bug720-repro result=complete pending=0 red=0 green=0 done=1
EXIT=0
```

The driver now starts at `gen` on the clean state, certifies the red,
makes it green, and refactors — `result=complete`, exit 0. The
"no gen artifacts" runner-error from the red evidence is gone.

## Unit tests (post-fix)

`dart test --preset=all test/plugins/tdd/run_command_test.dart --plain-name "bug 720"`
→ 3 passing:
- bug 720: a clean state with residual red evidence re-enters at gen instead of make
- bug 720: green and red claims without gen artifacts re-enter at gen — a state claim cannot skip gen
- bug 720: a red claim with gen artifacts still re-enters at make — the check is artifact existence, not a blanket re-drive

## Note on the generation pipeline entrypoint (out of scope)

When `zfa` is NOT resolvable on `PATH`, the spawned `make`'s generation
pipeline falls back to `Platform.resolvedExecutable` + `Platform.script`
(PipelineRunner tier 4), which for an AOT-compiled binary doubles the
executable path in the step argv (exit 64, usage error). With `zfa` on
`PATH` (tier 3) the pipeline resolves correctly — as in the green run
above. This is pre-existing PipelineRunner/StepRunner behavior,
independent of the #720 sequencing fix (StepRunner does not forward
`--zfa-bin` to spawned steps; the issue's own repro used an installed
`~/.local/bin/zfa`, which is a PATH-resolvable install layout).
