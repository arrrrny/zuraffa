# Bug Assessment: tdd make generation subprocess killed (exit -9) — memory-bounded execution

- **Slug**: tdd-make-subprocess-killed-memory
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/826
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd make` for acceptance behaviors spawns `zfa make <id> --no-entity` which is killed with SIGKILL (exit -9, OOM) inside the run loop. Run stops with `outcome=generation-error`. Direct invocation of the same command completes — so the kill happens in the loop's subprocess context. The failure is nondeterministic and transient: in-loop make fails, direct rerun is green, no state changed. This is the signature of the SIGKILL/OOM class: resource pressure inside the run loop's subprocess context. For the 120-spec corpus this is fatal: a corpus driver cannot distinguish "genuine red needing a fix" from "transient kill". https://github.com/arrrrny/zuraffa/issues/826

## Symptom

`zfa tdd make` for acceptance behaviors is randomly killed with SIGKILL (exit -9) during the run loop. The run stops with `outcome=generation-error`. Direct rerun of the same step succeeds — the failure is transient and nondeterministic. Affects specs 004 (A3, A4), 005 (A3), and 001 (U8 on fresh master).

## Reproduction

1. `zfa tdd run <feature>` with 20+ acceptance behaviors
2. Make step for an acceptance behavior spawns `zfa make <id> --no-entity`
3. Subprocess killed with SIGKILL (exit -9) — OOM
4. Direct rerun of same command succeeds — transient, nondeterministic

## Suspected Code Paths

- The run loop's subprocess spawning for `zfa make <id> --no-entity` — likely no memory ceiling or timeout
- The generation pipeline (analyzer/build) loaded by the spawned `zfa` — heavy memory footprint
- The outcome handling for generation failures — currently reports bare `generation-error` without classifying the kill reason

## Root Cause Hypothesis

Medium-high confidence: the spawned `zfa make` subprocess loads the full analyzer/build pipeline, which can exceed the memory ceiling (especially on CI/cloud with limited RAM). The OS kills it with SIGKILL (exit -9). The nondeterminism comes from memory pressure varying based on concurrent work, GC timing, and the specific features being analyzed. The kill is not reported as a classified verdict — just a bare `failed`/`generation-error`.

## Proposed Remediation

**Preferred**: (1) Wrap the generation subprocess with a bounded memory limit (`ulimit -v` or platform equivalent) and a hard timeout. (2) When the subprocess is killed, emit a classified verdict (`resource-limit` or `timeout`) with the exit code and a `--> fix:` line — never a bare `failed`. (3) When the plan is empty ("No active plugins"), record a no-op outcome instead of attempting the subprocess. (4) Add resource telemetry (RSS before/after, wall clock) to the JSON verdict for observability.

**Alternatives** (optional):
- Increase the memory ceiling rather than bounding it — simpler but does not prevent runaway generation from starving other work; not a systemic fix.

**Files likely to change**:
- The run loop subprocess spawning code (where `zfa make` is exec'd)
- The outcome/verdict emission code (to classify kill reasons)
- The empty-plan handling path (to short-circuit to no-op)

**Tests to add or update**:
- Regression test: run `zfa tdd run` on a fixture feature with 20+ acceptance behaviors; assert zero SIGKILLs
- Determinism proof: N consecutive full-loop runs on the fixture with zero transient stops
- Test that empty-plan behaviors produce a no-op outcome, not a crash

## Risks & Considerations

- Memory bounding may need platform-specific tuning (Linux vs macOS)
- Timeout value must be generous enough for legitimate generation work but short enough to prevent runaway
- The classified verdict format must be machine-parseable for corpus drivers
- Part of epic #848 (Wave 1 — unblock the loop) — fix ordering matters

## Open Questions

- [NEEDS CLARIFICATION: What is the current memory ceiling for subprocess spawning? Is it configurable?]
- [NEEDS CLARIFICATION: Is the empty-plan ("No active plugins") path already a no-op, or does it still spawn the subprocess?]
