# Bug Assessment — #1402

**Issue:** `zfa tdd make` — `--plain-name` lookup silently exits 79 ("No tests ran") when a hand-edited test name doesn't embed the behavior description verbatim
**Severity:** medium
**Source:** https://github.com/arrrrny/zuraffa/issues/1402

## Root cause

The make command's target-test invocations (drift check FR-003, skin-authoring
re-certification, post-generation re-run FR-007, per-behavior tolerance guard)
all substitute the behavior's plain name into the profile `single` template —
`dart test {file} --plain-name "{name}"` / `flutter test {file} --plain-name
"{name}"`. `--plain-name` is a literal SUBSTRING match against the OUTER
`test(...)` name. When a hand-edited test renames the outer `test('...')` so
it no longer contains the behavior description string verbatim, the runner
matches ZERO tests, prints "No tests ran." and exits 79.

Every make consumer grades that transcript as a generic failure
(`parseExecutedTestCount` → 0 → classifier `runnerError`; the drift check
treats exit != 0 as "still red" and proceeds into generation, which then
re-fails at the post-generation re-run with `generation-error`). No diagnostic
anywhere names the actual cause — the test name must embed the behavior
description verbatim — so the agent hand-driving the cycle must
reverse-engineer it (the workaround is documented in
`docs/zfa-tdd-guide.md` §8).

## Remediation (hard constraints)

Fix ONLY the make command's test runner invocation (fallback/remedy on exit
79). Do NOT change the core engine cycle, the verify-red logic, the
`--plain-name` flag semantics, or the spec-parser. One PR per bug.

Chosen remedy (issue's expected #1 best + #2 minimum):

1. **Zero-match detection** — a make target-test run whose transcript carries
   the runner's no-tests signature (exit 79 + "No tests ran") while the
   template carries `--plain-name` is a name-mismatch, never evidence.
2. **Whole-file fallback + warning** — make warns (`--plain-name` matched zero
   tests) and re-runs the WHOLE target file through the profile's existing
   `file:` template (`dart test {file}` / `flutter test {file}`), so the
   drift check / post-run grade real evidence instead of a phantom.
3. **Targeted remedy** — when the fallback also runs zero tests (or the
   profile carries no `file:` template), make emits the issue's remedy line:
   "test name must contain the behavior description verbatim — rename the
   test(...) to embed it", and the drift check misfire-stops (the same
   no-signal contract as the #742 timeout stop) instead of spending
   generation on a behavior no runner invocation can observe.

## Verification plan

- New regression test file (fixture harness, real `dart test` subprocesses):
  - zero-match + whole-file fallback → make proceeds on real evidence (warn
    present, no phantom stop);
  - zero-match + fallback also zero-match → targeted remedy text present,
    misfire-stop, no generation spend;
  - normal matching → output byte-identical to today (no fallback noise).
- `dart analyze` clean on changed files; `dart format .` zero diffs.
- Changed-file tests only (cloud disk constraint — no full-suite run).
