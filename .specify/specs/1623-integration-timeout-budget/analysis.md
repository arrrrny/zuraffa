# Analysis: 1623-integration-timeout-budget

- **Date**: 2026-09-15
- **Artifacts audited**: spec.md, plan.md, tasks.md, tdd/test-list.md
  (drafted), current HEAD tree (26a6fc0), issue #1623, issue #1187.

## Verdict: PASS — no unresolved drift

## Checks

1. **Coverage — every SC lands in plan design + tasks**:
   - SC-1 (B9b without override + green) → plan §3 → T003 (removal) +
     T004 (end-to-end proof). ✔
   - SC-2 (loud timeout diagnostic pinned) → plan §4 → T001 R5. ✔
   - SC-3 (240s scaled cold-source budget, full matrix) → plan §1–§2 →
     T001 R1–R4 + T002 (implementation). ✔
   - SC-4 (README contract + worked example) → plan §5 → T003. ✔
2. **Constraint — "fix test/helpers timeout budgeting only"**: the changed
   production surface is `test/helpers/run_zfa_source.dart` alone; B9b
   edits are budget-only (no assertion touched); R5 is a TEST of lib
   behavior, not a lib change — `lib/` diff stays empty. ✔
3. **Naming consistency** across plan/tasks: `kZfaColdSourceBaseTimeout`,
   `zfaColdSourceChildTimeout`, `resolveChildTimeout`,
   `_zfaColdSourceBudgetSpent` — identical spellings everywhere. ✔
4. **Ceiling invariant**: 240s base < 360s (B9b 6-min `Timeout`) and <
   480s (B9 8-min) at scale 1.0; higher scales documented via the existing
   `--timeout xN` guidance rather than silently capped. Consistent in
   spec Hard constraints, plan Risks, tasks T002 doc requirements. ✔
5. **Honesty of red evidence**: R1–R4 are true reds (API absent at HEAD);
   R5 is green-before-write (06ecc54 already shipped the behavior) and is
   declared a regression pin in BOTH plan (Test strategy) and tasks
   (T001 RED EVIDENCE note) — no fabricated red. Matches the 1505
   convention. ✔
6. **Issue acceptance-criteria mapping**: issue AC1→SC-1, AC2→SC-2,
   AC3→SC-3, AC4→SC-4. The issue's "Possible fix" bullets map to SC-2
   (loud AOT failure) and SC-3 (scaled first cold source spawn). ✔
7. **Existing-suite interactions**: `zfaDefaultChildTimeout` semantics
   unchanged → feature_flags scaled `Timeout` ceilings keep their
   guard-inside-ceiling property; `resolveChildTimeout` returns explicit
   timeouts verbatim, preserving the documented "explicit is not
   auto-scaled" contract that B9's sibling spawns rely on. ✔

## Findings (resolved during drafting)

- F1: B9b's stale comment claims a silent fallback that the no-JIT policy
  removed — folded into T003 (comment must state the CURRENT contract, not
  just be deleted, so the file keeps explaining its budget).
- F2: R5's red state — resolved as an explicit pin declaration (see check
  5) instead of a contrived timeout wait (a real 100s wait would be a
  slow test; the fake-runner TimeoutException propagates through the same
  expression into the same handler).

No artifact changes required after analysis.
