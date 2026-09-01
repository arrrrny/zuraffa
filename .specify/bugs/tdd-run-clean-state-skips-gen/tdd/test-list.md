# Test List: tdd run on clean state skips gen and fails make (bug 720)

---
feature: tdd-run-clean-state-skips-gen # bug dir (spec-kit's feature resolver errors for bug work; resolved per the bug extension's per-bug layout)
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 3 # issue.md Expected (start at gen -> verify-red -> make), assessment.md Remediation (inFlight null/empty AND no gen artifacts -> gen regardless of BehaviorState), assessment.md Risks (#682 resume semantics preserved)
planned_at: d6f7f517
updated_at: d6f7f517
suite_baseline: green
---

Scope note: the branch's production change is confined to the step-sequencing
logic in `lib/src/plugins/tdd/commands/run_command.dart` (`_stepsFor` gains a
gen-artifact existence guard; a `_genArtifactIds` helper resolves the feature's
`artifacts.json` registry against disk; the phase-1 call site passes the flag).
Existing driver tests that encoded artifact-blind state claims were re-anchored
to the new contract by registering gen artifacts (assertions unchanged).

## Inner loop: unit behaviors (driver-level, fake-zfa fixture)

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U1 | A clean state (no run-state.json, no artifacts.json records, no generated files) carrying residual red evidence re-enters every behavior at `gen`, never at `make` | issue.md Expected; assessment.md Root Cause | example | DONE | `test/plugins/tdd/run_command_test.dart::bug 720: a clean state with residual red evidence re-enters at gen instead of make` |
| U2 | GREEN and RED state claims without gen artifacts re-enter at gen regardless of the claim (a state claim cannot skip gen) | assessment.md Remediation ("regardless of the BehaviorState") | example | DONE | `test/plugins/tdd/run_command_test.dart::bug 720: green and red claims without gen artifacts re-enter at gen — a state claim cannot skip gen` |
| U3 | A RED claim WITH gen artifacts (registry record + recorded test file on disk) still re-enters at make — the check is artifact existence, not a blanket re-drive | assessment.md Risks ("interacts with the #682 fix") | example | DONE | `test/plugins/tdd/run_command_test.dart::bug 720: a red claim with gen artifacts still re-enters at make — the check is artifact existence, not a blanket re-drive` |

## Outer loop: acceptance behavior (real binary, end to end)

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| A1 | The real compiled `zfa tdd run` driver on the issue's exact clean state prints `A1 gen -> ok`, `A1 verify-red -> certified`, `A1 make -> green`, `A1 refactor -> clean` and completes exit 0 (the pre-fix binary printed `A1 make -> runner-error` with "no gen artifacts", exit 2) | issue.md Reproduction + Expected | characterization | DONE | Real-binary reproduction harness — scratch project + compiled `bin/zfa.dart`; red and green transcripts recorded in `../red-evidence.md` and `../green-evidence.md` (not a committed test: it needs a compiled binary, a resolved `dart test` scratch project, and `zfa` on PATH) |
