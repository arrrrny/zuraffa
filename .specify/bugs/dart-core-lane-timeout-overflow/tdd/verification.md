# TDD Verification — dart-core-lane-timeout-overflow

- **Audited**: 2026-09-15
- **Auditor**: LLM-guided fallback (engine detection `ZFA_MISSING` — no
  `.zfa.json` in this repo; the deterministic `zfa tdd verify` path requires
  the generated-artifact registry this bug's loop did not use after the
  driver's honest vacuous-green stop)
- **Verdict**: **PASS**

## Phase 1 — Test-first evidence

- The assertion surface (`test/tier_integrity_test.dart` B5/B6, later B7)
  was authored and run against the PRE-TAG tree before the fix was applied:
  the failing transcript is committed at ./red-evidence.md (`+5 -2`, B5
  enumerating the untagged heavyweight offenders, B6 the tier-only
  regression files). The driver's own certified red (A1, hash-chained entry
  in ./cycle-log.md) corroborates the same pre-fix tree.
- The tag application, the ci.yaml change and the pins landed together in
  one commit by nature of the fix (annotation metadata has no separate
  "implementation"); the red evidence above is the test-first proof.

## Phase 2 — Red-phase evidence

- RED: `+5 -2` on the pre-fix tree (see ./red-evidence.md — the B5 reason
  block names each offender file and its criterion).
- GREEN: `+8: All tests passed!` on the post-fix tree (B1–B7).
- The two repaired pre-existing master suites carry their own before/after
  evidence: bug_1388 (PathNotFoundException + reused verdict →
  `verdict=regenerated` + token in file, 2/2), pubignore guard (10-line
  missing-target list → empty, 3/3). See ./fix-notes-1388.md and
  ./cycle-log.md.

## Phase 3 — Test smells

- No vacuous guards: the pins assert on real structure (parsed tag sets,
  source-marker census, parsed workflow steps) and enumerate offenders in
  their failure reasons.
- No tautologies: the census criteria live in the test itself and were
  mutated below.
- The census is pure and fast (file reads only — no suites spawned), so the
  pin rides the lane it guards.

## Phase 4 — Deliberate-mutant sampling (no mutation tool wired; profile
fallback)

| Mutant | Expected killer | Result |
|--------|-----------------|--------|
| regression file stripped to tier-only `['regression']` | B6 | **killed** (B6 fails, enumerating the file) |
| spawn-heavy file stripped of its exclusion tag | B5 | **killed** (B5 fails, naming the file) |
| ci.yaml: drop `--concurrency=4` | B7 | **killed** (B7 fails: "re-serializes the lane back over its budget") |
| restore tree | — | 8/8 green |

The third mutant found a REAL gap mid-verification: FR-004 had no structural
pin (dropping the concurrency flag survived every existing test). Remediated
in-verification by adding B7; re-run kills the mutant.

## Phase 5 — Acceptance-criteria coverage

| AC | Evidence |
|----|----------|
| AC-1 (heavyweight ⇒ tagged) | B5 green post-fix; red-evidence.md pre-fix |
| AC-2 (regression tier invariant) | B6 green; 17+ tier-only files re-homed |
| AC-3 (structural pin prevents recurrence) | B5/B6/B7 + the three killed mutants |
| AC-4 (scoped parallelism, B1–B4 green) | B7 green; B1–B4 unchanged and green |
| AC-5 (residual lane < 8 min) | Local `-j4` full-lane run: **5:06.71 wall** (5,940 passed) on a machine under concurrent IDE test churn; the PR's dart_core CI run is the dedicated-hardware confirmation |

## Verdict

**PASS** — test-first evidence, red→green discipline, smell-free pins, all
sampled mutants killed, and full AC coverage. One gap found and closed
during the audit (B7).
