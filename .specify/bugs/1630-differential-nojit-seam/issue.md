# Issue — 1630 (differential stub entries are AOT-compiled by the no-JIT policy)

GitHub: https://github.com/arrrrny/zuraffa/issues/1630

## Symptom

After #1629 (no-JIT: every zfa child is a compiled binary),
`test/plugins/tdd/commands/corpus_differential_command_test.dart` fails
locally 7/13 and in CI's `dart_core` lane (master red from the #1629 merge
run on).

```
zfa tdd corpus differential: 1 entry(s) from origin/master (deadbeefcafe) to HEAD (deadbeefcafe)
ZfaCompilationException: dart compile exe failed for "/tmp/diff_cmd_*/scratch-root/wt-from/bin/zfa.dart" (exit 254)
  stderr:
bin/zfa.dart: Error: No 'main' method found.
Error: AOT compilation failed
  package:zuraffa/src/cli/zfa_executable.dart  ZfaExecutable._compileCached
  package:zuraffa/src/plugins/tdd/services/differential_ref_runner.dart  DifferentialRefRunner.runEntry
  package:zuraffa/src/plugins/tdd/commands/corpus_differential_command.dart  CorpusDifferentialCommand._run
```

The test's fake `worktree add` writes a **stub** entrypoint
(`bin/zfa.dart` → `void m(){}`) and intercepts every spawn through the
injectable `DifferentialSpawner`. The no-JIT policy compiles the worktree
entrypoint *before* the spawner sees the step, so the stub is handed to a
real `dart compile exe` and the runner throws.

## Root cause

`CorpusDifferentialCommand` wires `DifferentialRefRunner` with test seams
for the spawner and the git runner, but not for the compile step.
`DifferentialRefRunner` already accepts `ZfaEnsureCompiled? ensureCompiled`
(default `ZfaExecutable.ensureCompiled`); the command never forwards an
override, so a scripted stub is really compiled.

## Fix

Forward a `ZfaEnsureCompiled? ensureCompiled` override through
`CorpusDifferentialCommand` (the same seam shape step_runner / pipeline_runner
/ corpus_step_runner already carry), and have the command test inject a fake
that maps the candidate to a deterministic artifact path (preserving the
`wt-from` / `wt-to` worktree labels its fakes key on).

## Related, NOT this bug

`test/plugins/tdd/commands/bug_1388_gen_traces_fingerprint_test.dart` B1 and
`test/pubignore_export_guard_test.dart` also fail in `dart_core`, but they
already failed on the #1628 merge run (before #1629) — pre-existing red,
tracked separately.
