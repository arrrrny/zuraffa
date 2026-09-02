# Bug Assessment: tdd gen --adopt + zfa tdd reset — first-class recovery instead of hand-edits

- **Slug**: tdd-recovery-commands
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/840
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

During the 120-spec run, hand-edits to run-state.json and directory moves were required because recovery commands don't exist. Hand-edits are the trust violation VISION forbids; the system must own its state. Required: `zfa tdd gen <id> --adopt` (register unowned files), `zfa tdd reset <feature>` (revert to clean), `zfa tdd doctor <feature>` (reconcile + prescribe). https://github.com/arrrrny/zuraffa/issues/840

## Symptom

After crashes, interrupted runs, or merges, files exist on disk that are not registered in artifacts.json (unowned). There is no command to adopt them, reset a feature, or diagnose the state. Operators must hand-edit run-state.json, which VISION forbids.

## Reproduction

1. Run `zfa tdd run <feature>` — crash or interrupt mid-run
2. Files exist on disk (generated tests/subjects) but artifacts.json doesn't know about them
3. `zfa tdd run` refuses (ownership conflict) or `zfa tdd refactor` refuses (no evidence)
4. No recovery command exists — operator must hand-edit

## Suspected Code Paths

- `artifacts.json` — ownership registry, no adopt mechanism
- `run-state.json` — state tracking, no reset mechanism
- `cycle-log.md` — evidence trail, no reconciliation
- No `zfa tdd doctor` command exists

## Root Cause Hypothesis

High confidence: the TDD pipeline has no first-class recovery commands. When state becomes inconsistent (crash, interrupt, merge), operators must hand-edit files to recover. This is a design gap, not a code bug — the system lacks the commands it needs.

## Proposed Remediation

**Preferred**: Implement three recovery commands: (1) `zfa tdd gen <id> --adopt` — verify unowned files match generated artifact shape, register ownership in artifacts.json, audit-logged. (2) `zfa tdd reset <feature>` — drop artifacts registry entries + generated tests/subjects owned by the feature, never touch foreign files, print diff summary before acting. (3) `zfa tdd doctor <feature>` — reconcile the three stores (per #828), prescribe exactly one of: resume / reset / adopt as a `fix` line. All three emit JSON verdicts and respect the exit protocol.

**Alternatives** (optional):
- Hand-editing run-state — explicitly forbidden by VISION; kills trust.

**Files likely to change**:
- New `adopt` subcommand for `zfa tdd gen`
- New `zfa tdd reset` command
- New `zfa tdd doctor` command
- JSON verdict emission for all three

**Tests to add or update**:
- `--adopt` registers unowned files correctly
- `reset` drops only owned files, never touches foreign
- `doctor` detects drift and prescribes the correct action (resume/reset/adopt)
- All three emit valid JSON verdicts

## Risks & Considerations

- `reset` must NEVER delete foreign files — strict ownership check required
- `--adopt` must verify content shape, not blindly register anything
- `doctor` must be deterministic — same state always produces same prescription
- Part of epic #848 (Wave 1 — unblock the loop)

## Open Questions

- [NEEDS CLARIFICATION: Should `doctor` be a standalone command or a subcommand of `zfa tdd`?]
- [NEEDS CLARIFICATION: What is the "content shape" verification for `--adopt` — AST check, structure check, or just path pattern?]
