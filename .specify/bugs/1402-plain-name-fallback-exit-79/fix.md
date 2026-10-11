# Fix — #1402 (`zfa tdd make` exit-79 name-mismatch fallback/remedy)

**Branch:** `fix/1402-plain-name-fallback-exit-79`
**Scope guard:** ONLY the make command's test runner invocation. The core
engine cycle, verify-red logic, `--plain-name` flag semantics, and the
spec-parser are untouched. One PR for one bug.

## Change surface

`lib/src/plugins/tdd/commands/make_command.dart` (+129 / −4):

1. **Profile `file:` template load** (optional, degrades to null): the
   whole-file fallback reuses the profile's existing batched runner
   (`dart test {file}` / `flutter test {file}`) — the same template the
   batched verify-red lane uses. A profile without a `file:` key never
   fabricates a runner invocation (remedy-only path).
2. **`_noTestsRan(RunRecord)`** — the runner's no-tests signature:
   `startedProcess && exitCode == 79 && output contains "No tests ran"`.
3. **`_runTargetTest(...)`** — the single wrapper ALL FOUR make target-test
   invocations now route through (drift check FR-003, skin-authoring
   re-certification, post-generation re-run FR-007, per-behavior #737
   tolerance guard):
   - run the profile `single` template as today;
   - on a zero-match under a `--plain-name` template: WARN with the exact
     resolved command, then fall back to the WHOLE target file through the
     `file:` template and return that run (real evidence replaces the
     phantom);
   - when the fallback also runs zero tests (or is unavailable): print the
     targeted remedy — "test name must contain the behavior description
     verbatim — rename the test(...) to embed it (issue #1402)" — and
     return the ORIGINAL record (callers keep today's honest grading).
4. **Drift-check misfire-stop**: a STILL-zero-match drift record (fallback
   exhausted) stops make BEFORE generation with the same no-signal contract
   as the #742 timeout stop (`outcome=runner-error`) — no more spending a
   generation pipeline a phantom can never certify.

## Semantics preserved

- No zero-match → byte-identical behavior (the wrapper returns the single
  run untouched; U3 proves no #1402 noise on healthy cycles).
- `--plain-name` flag semantics unchanged — the guard engages only when the
  template itself carries the flag; verify-red is untouched.
- All failure paths keep their existing outcomes (`runner-error`,
  `generation-error`, `skipped`, ...); the fix ADDS diagnostics and, where
  observable evidence exists, substitutes real evidence for the phantom.

## Tests

`test/plugins/tdd/bug_1402_plain_name_fallback_test.dart` (real `dart test`
subprocesses in throwaway projects, the repo's bug-test convention):
U1 fallback + honest skip, U2 remedy + misfire-stop (no green evidence),
U3 healthy cycle no-noise, U4 fileless profile remedy-only path.
RED→GREEN proved in-session: U1/U2/U4 fail on the pre-fix binary, all four
pass on the fixed binary (see tdd/verification.md).
