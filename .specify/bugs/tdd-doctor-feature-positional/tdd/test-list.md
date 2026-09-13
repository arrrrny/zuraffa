# Test List: tdd-doctor-feature-positional (#1585)

**Feature**: `.specify/bugs/tdd-doctor-feature-positional` (bug TDD mode)
**Source**: `spec.md` — derived via the LLM-guided fallback path
(speckit.tdd.plan; engine detection: ZFA_MISSING — no `.zfa.json` in this repo)
**Suite**: `test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart`
(slow-tagged — `dart test --preset=all <file>` is the only lane that runs it)

## Unit behaviors

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U1585-1 | the suite's `doctor()` helper invokes `zfa tdd doctor <feature> --project <root>` — the feature POSITIONAL, the form `DoctorCommand` declares — so the arg parser accepts it and the verdict is reached | FR-001 | unit | DONE | test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart |
| U1585-2 | the four previously usage-error doctor tests reach their assertions: tampered hash chain, pending journal, consistent stores, green-claim-without-evidence | FR-002 | unit | DONE | same |
| U1585-3 | `doctor` recomputes each schema-1 entry's chain hash (and the `prev-hash` linkage) and reports a mismatch as `hash chain broken` drift with a `--> fix:` line, exit 1 — the #828 walk restored after the #840 rework dropped it | FR-003 | unit | DONE | same |
| U1585-4 | legacy hash-less entries stay valid: the consistent-store fixture seeds them and the doctor reports no drift (the walk never fails what it cannot verify) | FR-003 | unit | DONE | same |
| U1585-5 | the zero-drift pin reads the verdict envelope (`verdict: healthy`, empty `drifts`) on the final stdout line, not the retired `drifts=<n>` summary | FR-004 | unit | DONE | same |
| U1585-6 | the walk's LINKAGE arm is pinned in isolation: a trail whose `- prev-hash:` no longer chains is reported as `does not link` drift (a content-only walk reads it as healthy) | FR-003 | unit | DONE | same |

## Acceptance behaviors

| id | behavior | criterion | state |
| -- | -------- | --------- | ----- |
| A1585-1 | the pre-fix helper reproduces the issue exactly: usage text captured, `+9 -4` | AC-1 | DONE |
| A1585-2 | the fixed suite is `14/14` — the four doctor tests exercise the real drift logic | AC-2 | DONE |
| A1585-3 | a schema-1 entry edited after certification (`- exit: 1` → `- exit: 2`) is reported as drift, never as "stores agree" | AC-3 | DONE |
| A1585-4 | consistent stores yield `verdict: healthy` + empty `drifts` and exit 0 | AC-4 | DONE |

## Coverage

- U1585-1 traces to FR-001 (A1585-1/A1585-2).
- U1585-2 traces to FR-002 (A1585-2): the four masked tests now execute their
  assertions; the tampered-hash case is the one that surfaced the deeper defects.
- U1585-3 + U1585-4 trace to FR-003 (A1585-3): the tampered entry is caught, the
  legacy-format entries are tolerated.
- U1585-6 traces to FR-003's linkage arm (A1585-3): added during verification —
  the mutation audit showed the content arm was pinned by U1585-3 but the
  linkage arm had no pin, so a walk that only recomputed digests survived.
- U1585-5 traces to FR-004 (A1585-4).
- Out of scope: the `--repair` GC path and the other doctor gates — untouched by
  this fix; the sibling doctor suites are swept as the regression guard.
