---
feature: 1472-refactor-build-gate-warnings
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 7
planned_at: local
updated_at: local
suite_baseline: green
---

# Test List: Refactor build gate refuses on errors only; zfa binary pinned to the driving version

The refactor pass registry misfire-stops when the `build` pass exits
non-zero, and the `zfa build` gate refuses on errors OR warnings — so a
warnings-only refusal deadlocks the pass that would clean it. The loop is
outside-in: the acceptance behaviors reproduce the issue through the public
CLI surface (`TddFixture` + `CliRunner`), the unit behaviors pin the registry
decision table through the fake `ProcessExecutor`, the pinning behaviors
exercise real `--version` probes against fake PATH zfa scripts with the
driving entrypoint injected (the real `bin/zfa.dart` costs ~45s in a cold JIT
compile, past the probe's 30s bound, so it would read as unprovable). Every
behavior traces to a spec success criterion.

## Outer loop: acceptance behaviors

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| A-1472-1 | a refactor whose build pass is refused on warnings only completes through format+fix (outcome=refactored, applied≥1 — the fix pass really ran) | SC-1, SC-3 | cli | GREEN | `A-1472-1` in `test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart` |
| A-1472-2 | a refactor whose build pass fails with analyzer errors still misfire-stops runner-error | SC-2 | cli | GREEN | `A-1472-2` in `test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart` |
| A-1472-3 | the profile's `analyze-gate: warnings-blocking` opt-in restores the legacy refusal end-to-end | SC-5 | cli | GREEN | `A-1472-3` in `test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart` |

## Inner loop: unit behaviors — registry decision table (`RefactorPasses.run`)

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| U-1472-1 | build pass exits 1 with the gate's 0-errors/N-warnings verdict → registry continues; format and fix still run; result.completed | SC-1 | unit | GREEN | `U-1472-1` |
| U-1472-2 | the recorded build RefactorAction keeps the honest exit 1 and raw refusal output | SC-3 | unit | GREEN | `U-1472-2` |
| U-1472-3 | the tolerated verdict is logged with the gate's own counts and names warnings non-blocking (never "did not compile cleanly") | SC-3 | unit | GREEN | `U-1472-3` (captured print) |
| U-1472-4 | build refusal carrying ≥1 error keeps the misfire-stop (failedPass=build, fix never runs) | SC-2 | unit | GREEN | `U-1472-4` |
| U-1472-5 | a non-gate failure class (no verdict line, e.g. build_runner crash) keeps the misfire-stop | SC-2 | unit | GREEN | `U-1472-5` |
| U-1472-6 | gate message claims 0 errors but raw output carries `error -` lines → misfire-stop (safe-failure) | SC-4 | unit | GREEN | `U-1472-6` |
| U-1472-7 | `warningsBlocking: true` restores the legacy refusal for a warnings-only output | SC-5 | unit | GREEN | `U-1472-7` |
| U-1472-8 | a timed-out build never qualifies for the arm even with a gate line in its output | SC-2 | unit | GREEN | `U-1472-8` |
| U-1472-9 | a build pass that did not start never qualifies | SC-2 | unit | GREEN | `U-1472-9` |
| U-1472-10 | format/fix failures keep the misfire-stop unchanged (the arm is build-only) | SC-2, SC-7 | unit | GREEN | `U-1472-10` |
| U-1472-18 | a voluminous verdict logs a capped sample (10) of the `warning -` lines plus the `... N more warning(s)` remainder | SC-3 | unit | GREEN | `U-1472-18` (captured print) |

## Inner loop: unit behaviors — binary pinning (`zfaBuildCommand`)

| id | behavior | traces | kind | state | test |
|----|----------|--------|------|-------|------|
| U-1472-11 | a PATH zfa whose `--version` differs from the driving version → build command pinned to the driving entrypoint (not the PATH zfa) | SC-6 | unit | GREEN | `U-1472-11` |
| U-1472-12 | a PATH zfa reporting the driving version stays the build command (bug #717 contract intact) | SC-6, SC-7 | unit | GREEN | `U-1472-12` |
| U-1472-13 | a PATH zfa with unprovable version (empty stdout) keeps the #717 resolution (silence rule) | SC-6 | unit | GREEN | `U-1472-13` |
| U-1472-14 | the pin proves BOTH sides: a replacement whose probe differs from the driving version keeps the #717 candidate (no pin line) | SC-6 | unit | GREEN | `U-1472-14` (captured print, injected resolver) |
| U-1472-15 | a replacement whose probe is unprovable keeps the #717 candidate | SC-6 | unit | GREEN | `U-1472-15` |
| U-1472-16 | a driving entrypoint identical to the candidate is a no-op — no re-route, no pin line | SC-6 | unit | GREEN | `U-1472-16` (captured print) |
| U-1472-17 | an unresolvable driving entrypoint (StateError) fails open to the #717 candidate | SC-6 | unit | GREEN | `U-1472-17` |

## Evidence

- Red evidence: recorded in `tdd/cycle-log.md` per behavior (failed for the
  right reason pre-fix).
- Green evidence: same entries post-fix, plus `tdd/verification.md`.
