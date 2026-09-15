# Fix — 1630 (differential compile seam)

## Change surface

| File | Change |
|------|--------|
| `lib/src/plugins/tdd/commands/corpus_differential_command.dart` | Constructor gains `ZfaEnsureCompiled? ensureCompiled` (the same no-JIT seam shape `step_runner` / `pipeline_runner` / `corpus_step_runner` carry), stored as `_ensureCompiledOverride` and forwarded to `DifferentialRefRunner(ensureCompiled: …)`. Production passes nothing → the default `ZfaExecutable.ensureCompiled` still applies (unchanged behavior). |
| `test/plugins/tdd/commands/corpus_differential_command_test.dart` | Injects the fake compile seam (`candidate.replaceAll('/bin/zfa.dart', '/bin/zfa')` shape — derives the worktree artifact from the candidate so the `wt-from` / `wt-to` labels the fakes key on survive), and reads the worktree executable from `command.first` (a zfa step now spawns the compiled artifact itself, not `dart <worktree>/bin/zfa.dart`). |

## Why this shape

The no-JIT policy's compile step belongs to the runner (it must compile the
ref worktree's real entrypoint in production). What was missing is the
*test* seam: `DifferentialRefRunner` had `ensureCompiled` but the command —
the only production constructor — did not forward it, so the command-level
tests could not script a stub entrypoint. Adding the seam keeps the policy
intact (no `ZFA_ALLOW_JIT` here, no JIT fallback) and makes the scripted
fixtures hermetic again: no real `dart compile exe` runs in unit tests.

## Verification

See `test.md`.
