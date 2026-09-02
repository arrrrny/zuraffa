# Bug Assessment: cycle-log evidence integrity — run-state, artifacts, and cycle-log must never disagree

- **Slug**: tdd-cycle-log-evidence-integrity
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/828
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Three stores (run-state.json, artifacts.json, cycle-log.md) are updated at different times by different steps. An interrupted run leaves them inconsistent — run-state says green/done while cycle-log has no matching evidence entries. Refactor then hard-stops the whole corpus because it correctly requires evidence. https://github.com/arrrrny/zuraffa/issues/828

## Symptom

After an interrupted run or mid-loop stop, `run-state.json` claims a behavior is green/done but `cycle-log.md` lacks the corresponding red→green→refactor evidence entries. `zfa tdd refactor` correctly refuses to proceed (no evidence), hard-stopping the whole corpus. The three stores disagree.

## Reproduction

1. Run `zfa tdd run <feature>` — interrupt mid-loop (Ctrl+C, OOM kill, etc.)
2. Resume — run-state says some behaviors are green/done
3. `zfa tdd refactor` refuses: cycle-log lacks evidence for those behaviors
4. The three stores are inconsistent

## Suspected Code Paths

- `run-state.json` — per-behavior state tracking (updated by the run loop)
- `artifacts.json` — generated file registry (updated by gen step)
- `cycle-log.md` — evidence trail (updated by verify-red/make/refactor steps)
- The run loop's step execution — updates stores at different times, not transactional
- The refactor preflight — checks cycle-log for evidence, correctly refuses when missing

## Root Cause Hypothesis

High confidence: the three stores are updated independently by different steps without transactional guarantees. An interrupted run leaves them in an inconsistent state. The system lacks reconciliation on resume — it trusts run-state without verifying cycle-log evidence.

## Proposed Remediation

**Preferred**: (1) Single transactional writer: every step appends evidence AND updates state in one write-ahead commit — journal first, then apply, then fsync both stores. (2) On resume, `zfa tdd run` reconciles: any behavior claiming green/done without complete evidence in cycle-log is reset to the earliest incomplete step and re-driven. (3) Evidence schema versioned with tamper-evident hash chain per behavior. (4) `zfa tdd doctor` reports drift with `--> fix:` line.

**Alternatives** (optional):
- Hand-editing run-state as a workaround — explicitly forbidden by VISION; kills trust.

**Files likely to change**:
- The run loop's step execution (transactional writes)
- Resume/reconciliation logic
- Evidence schema (hash chain)
- New `zfa tdd doctor` command

**Tests to add or update**:
- Interrupted run → resume → stores consistent
- `zfa tdd doctor` detects drift and prescribes fix
- Hash chain tamper detection

## Risks & Considerations

- Transactional writes add complexity; must not slow down the normal path
- Hash chain must be lightweight (fast to compute)
- Reconciliation must not lose legitimate state
- Part of epic #848 (Wave 1 — unblock the loop)

## Open Questions

- [NEEDS CLARIFICATION: Is the hash chain per-behavior or per-run?]
- [NEEDS CLARIFICATION: Should `zfa tdd doctor` be a separate command or integrated into `zfa tdd run`?]
