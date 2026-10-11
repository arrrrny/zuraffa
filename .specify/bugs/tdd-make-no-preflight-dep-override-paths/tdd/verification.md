---
bug: tdd-make-no-preflight-dep-override-paths
issue: 1303
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: session 2026-09-08 (branch fix/1303-tdd-make-no-preflight-dep-override-paths, pre-commit)
behaviors: 3
proven: 3
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: unmeasured # quick audit — no mutation run on this bug fix (see gaps)
engine: fallback LLM-guided audit # repo has no .zfa.json — the extension's Step 0 routes to the fallback path; `zfa tdd verify --feature` needs a spec feature's artifacts.json, which a bug fix does not have
suite: fast 97/99 chunks green (chunked, resumable driver over the stock chunk list) + the 2 exception chunks 255 passed / 2 pre-existing failures (test/cli 208/1, test/plugins/state 46/1) / targeted slow suites 46 + 4 + 2 passed, 0 failed
---

# TDD Verification: bug 1303 — dependency_overrides path preflight + honest resolution-error classification

**Verdict: PASS.** All three remediation behaviors carry recorded red-then-green
evidence from real runs in this session, all three success criteria from the
assessment are PROVED by tests, `dart analyze` on the changed set is clean, the
fast tier of the full suite shows zero new failures, and the two failing suites
anywhere in the tree are PROVEN pre-existing on unmodified `master` (via
`git stash` re-runs). The one gap keeping this from a rubric-perfect score:
mutation strength was not measured on this disposable agent (see Gaps).

## Audit independence disclosure

The same session authored the fix, the tests, and this audit. Mitigations
applied: every RED run executed against the unmodified tree and its failure
mode captured verbatim BEFORE the corresponding fix landed; every GREEN number
below comes from a real `dart test` process in this session, not from memory;
the two suspicious full-suite failures were re-run on a stashed (fix-free)
tree and PROVEN pre-existing rather than assumed away.

## Test-first evidence

The RED phase ran BEFORE any source change. Exact failure modes from the
unmodified tree:

| Behavior (assessment remediation) | RED evidence (verbatim failure mode) | GREEN evidence |
| --- | --- | --- |
| (1) Preflight validates every `dependency_overrides[*].path` target BEFORE the pipeline starts | `test/plugins/tdd/services/dependency_override_preflight_test.dart` fails to LOAD — `Undefined name 'DependencyOverridePreflight'` (the gate does not exist); command-level make/run tests load but behave as today | 8/8 service unit tests pass (map-form stale path, the exact issue repro shape `../../zuraffa_flutter`, version-constraint overrides NOT validated as paths, valid path passes, non-path overrides ignored, no-section vacuous, missing pubspec fail-open, honest line rendering) |
| (2) Invalid path → honest `❌ preflight:` + `--> fix:` verdict, exit 3 (SPEC 917 drift class), zero work spawned | make test: `Expected: <3> / Actual: <1>` (today make proceeds past the stale override and dies later as not-certified-red); run test: `Expected: <3> / Actual: <1>` — and the run took 42 s spawning real pipeline steps on a project whose every step was doomed: the wasted-rebuild evidence itself | make refusal test passes (exit 3, `❌ preflight: dependency_overrides[...]`, `(no pubspec.yaml`, `--> fix: ... zfa tdd make`, `outcome=preflight-red`, no `zfa tdd make: behavior` resolution banner — refusal precedes ALL work) + negative control (resolvable override does NOT trip the gate); run refusal test passes (exit 3, `result=corrupt-state` summary, no `[run]` lines, journaled preflight_red) — now <1 s |
| (3) Skip the clean-cache retry when the failure is a pub RESOLUTION error (non-resolution retry untouched) | classifier: `Member not found: 'BuildCommand.reportsPubResolutionError'` (compile red); subprocess test red for the RIGHT reason — the retry fires on ANY failure today | 11/11 classifier assertions pass (`version solving failed` → true, `No pubspec.yaml found for package` → true, compile errors → false) and the slow subprocess test passes: a fixture with a stale path override runs `zfa build`, the output contains NO `Retrying with clean cache`, DOES contain the honest `resolution error` classification + `--> fix:` line (21 s real subprocess run) |

## Suite evidence (real runs, this session)

- `dart analyze` (changed set: build_command.dart, make_command.dart,
  run_command.dart, generation_plan.dart, dependency_override_preflight.dart) —
  **No issues found.** Whole-repo analyze: 250 issues on BOTH the fix tree and
  the stashed clean tree (corpus/specs fixture URIs) — zero delta from this fix.
- `dart format .` — repo-wide pass; the only reformatted files in the fix's
  scope are the five changed/new Dart files (3 unrelated pre-existing format
  drifts in corpus/specs fixtures were reverted, out of scope for this PR).
- Full fast suite, chunked disk-safe runner (`tools/run_tests_chunked.sh`
  chunk list; resumable driver because the sandbox reaps background
  processes): **97/99 chunks ALL TESTS PASSED, zero new failures.**
  - `test/cli` — 208 passed / 1 failed
    (`BootstrapRoutingIndexWriter emits an empty getAllRoutes barrel`) —
    **PROVEN pre-existing**: same failure on the stashed clean tree.
  - `test/plugins/state` — 46 passed / 1 failed (SC-3 fixture-matrix golden:
    goldens pin `Generator version: 6.1.0`, the repo generates 6.2.0) —
    **PROVEN pre-existing**: same failure on the stashed clean tree.
- Targeted slow suites for the changed build path:
  - `test/commands/build_command_unit_test.dart` — **46 passed / 0 failed**.
  - `test/commands/build_command_slang_stage_test.dart` — **4 passed / 0 failed**.
  - `test/commands/bug_1303_build_retry_skip_test.dart` — **2 passed / 0 failed**
    (classifier + the real-subprocess retry-skip proof).
- `test/commands/build_command_test.dart` (#276 subprocess integration): 1/5 —
  the four failures (`Actual: <2>` from the child `zfa build`) reproduce
  IDENTICALLY on the stashed clean tree — sandbox-environment-dependent
  pre-existing failures (fixture `dart pub get` inside the child), flagged
  here honestly and NOT counted against this fix.

## Success criteria — PROVED vs not

1. **PROVED** — all `dependency_overrides[*].path` targets are validated
   before the pipeline starts (service unit tests + make/run refusal tests +
   negative control).
2. **PROVED** — invalid paths emit the honest `❌ preflight:` verdict with the
   `--> fix:` line and exit 3 (drift class); make prints
   `outcome=preflight-red`, run prints `result=corrupt-state` and journals
   `preflight_red` with zero steps spawned.
3. **PROVED** — the clean-cache retry is skipped for pub resolution errors
   (real subprocess proof) and NON-resolution failures keep the retry
   (classifier assertions + the untouched #276 retry contract in
   build_command_unit_test 46/46).

## Constraints compliance

- Only preflight validation + error classification changed: no
  `dependency_overrides` format change, no retry-logic change for
  non-resolution errors, no new subcommands.
- One PR per bug; `Closes #1303` in the PR body.
- Hard-constraint check via `git diff`: build_command.dart's retry branch
  still fires for every non-resolution failure; the only new branch is the
  classification short-circuit.

## Gaps

- **Mutation strength unmeasured** — the mutation harness
  (`zfa tdd verify` / mutation_test.xml) is wired for spec features'
  artifacts.json, not bug-record fixes, and a full mutation pass on this
  disposable agent would fill the disk (the same reason the stock fast suite
  runs chunked here). Compensating evidence: the test-first table above pins
  each behavior to a distinct assertion, and the classifier's negative cases
  (compile errors keep the retry) guard the misclassification direction.
- `zfa doctor` preflight (the issue's "ideally" item) is NOT in this change —
  the brief's hard constraints scope the fix to `tdd make` / `tdd run` +
  build classification only.
