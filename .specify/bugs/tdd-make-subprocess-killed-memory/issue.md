# Bug Issue: [TDD-120] Fix #796 root cause: tdd make generation subprocess killed (exit -9) — memory-bounded subprocess execution

- **Slug**: tdd-make-subprocess-killed-memory
- **Fetched**: 2026-09-02
- **Issue**: 826
- **URL**: https://github.com/arrrrny/zuraffa/issues/826
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

Context: Goal is to build all 120 ZikZak specs 100% via `zfa tdd`. No compromises — gates stay strict. This is the #1 blocker observed on specs 004/005: the make step dies.

`zfa tdd make` for acceptance behaviors spawns `zfa make <id> --no-entity` which is killed with SIGKILL (exit -9, OOM) inside the run loop. Run stops with `outcome=generation-error`.

Observed on 004-dependency-injection (A3, A4) and 005-hive-caching-layer (A3). Direct invocation of the same command completes (prints "No active plugins to run") — so the kill happens in the loop's subprocess context.

Required (system fix, not symptom):
1. Root-cause the SIGKILL: memory ceiling per subprocess (likely the spawned `zfa` loading the analyzer/build pipeline). Execute generation steps with bounded memory and a hard timeout that REPORTS, not dies silently.
2. Per VISION (errors are an API): when a generation subprocess fails, emit machine-actionable verdict — exit code + `--> fix:` line. exit -9 is not a verdict.
3. The generation step for a behavior whose plan is empty ("No active plugins") should be a recorded no-op outcome, not a crash path.
4. Regression test: run `zfa tdd run` on a fixture feature with 20+ acceptance behaviors on CI; assert zero SIGKILLs.

## Comments

**arrrrny** (2026-09-02): "Part of epic #848 (Wave 1 — unblock the loop). Closing this without the epic context loses the dependency ordering."

**arrrrny** (2026-09-02): "Fresh evidence on current master (post-VISION commit 6921c730): Spec 001-app-bootstrap, fresh project, current binary — a feature that previously completed done=21 now stops mid-loop at U8:make. Immediate direct rerun of the SAME step on the SAME state completes green. The failure is nondeterministic and transient — in-loop make fails, direct rerun is green, no state changed. This is the signature of the SIGKILL/OOM class: resource pressure inside the run loop's subprocess context that does not reproduce standalone. For the 120-spec corpus this is fatal: a corpus driver cannot distinguish 'genuine red needing a fix' from 'transient kill'. Required validation: (1) determinism proof — N consecutive full-loop runs on a 20+-behavior fixture with zero transient stops; (2) resource telemetry around each generation subprocess (RSS before/after, wall clock) emitted in the JSON verdict; (3) any subprocess kill must surface as a classified verdict (resource-limit), never a bare 'failed'."
