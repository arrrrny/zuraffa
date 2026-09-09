# Analysis — Spec 1324 (cross-artifact consistency)

`/speckit.analyze` pass over spec.md, plan.md, tasks.md,
tdd/test-list.md. Status: PASS — no blocking findings.

## Coverage matrix

| SC | Behaviors | Impl tasks | Notes |
|----|-----------|------------|-------|
| SC-1 | B1 | T1, T2 | the corrupt-registry repro shape; the in-flight-gen variant is covered by the same `_stepsFor` guard (post-condition on the window, not on the branch) |
| SC-2 | B2, B3 | T3 | B2 = green-evidence arm; B3 = `sawUnexpectedGreen` arm; both keep the #1329 diagnostic recording |
| SC-3 | B4, B5 | T4 | B4 = detection; B5 = the three fail-open/priority guards |
| SC-4 | B6, B7 | — (invariants) | no implementation surface; guarded by the tests only |

## Consistency checks

- Terminology: `stale-artifacts` (stop result + doctor verdict),
  `prescription=reset`, `current artifact generation` (= the
  tombstone-filtered green-evidence set) — used identically across all
  artifacts.
- Scope guard: no task touches the core engine cycle, gen pipeline,
  make pipeline, verify gate, cycle-log format, run-state schema, or
  registry schema (spec Out-of-scope respected; the non-atomic registry
  append is documented as trigger, not fixed here).
- Exit-code contract: the new stop reuses exit 1 (stopped class); the
  new result token flows through `verdictForDriverResult` → receipt
  verdict `error`, journal gateState `red` — no vocabulary file changes
  required.
- Doctor priority: the new check slots after evidence-without-artifact
  (2d) and before import-resolution (2b); B5(c) pins the priority.
- Test tiers: all behaviors are `@Tags(['slow'])` driver tests over the
  scripted fake zfa (no real `dart test` children) — single-file runs
  only, per the cloud-agent disk ceiling.

## Findings (non-blocking)

1. The doctor check compares the LAST green entry per behavior; a
   behavior with multiple green entries is judged by its latest
   certification — matches the driver's `lastEntryFor` convention.
2. `_stepsFor`'s new guard is a post-condition (fires only when
   `start == 0`), so `verify-red`-starting windows (blocked claims) are
   intentionally untouched — a blocked contract behavior with green
   evidence keeps re-entering at verify-red, which re-certifies
   honestly before make.
3. B2's fixture needs no registry record at all (a `red` claim keeps
   the make-starting window regardless of `hasGenArtifacts`) — the test
   documents this so the fixture is not mistaken for the B1 shape.
