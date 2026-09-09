# Verification: 1430-refactor-refresh-evidence

**Verdict**: PASS

**Date**: 2026-09-09 | **Auditor**: spec-whole tdd-verify (cold-context audit,
time-boxed per operator instruction — heavyweight whole-suite E2E runs
deferred to CI, see Scope note)

## Phase 1 — Test-first evidence

| Behavior | Red evidence | Green evidence |
| -------- | ------------ | -------------- |
| A-1430-1 | RED pre-fix: make refuses `subject-drift` on the reformatted certified subject (certified `b64cab8e…` vs current `20a0351a…`, `outcome=subject-drift`, exit 1) — the issue's exact dead end (cycle-log Cycle 1) | GREEN: `subject drift accepted (issue #1430)` provenance note, `outcome=skipped`, exit 0 — no `--re-certify` |
| A-1430-2 | RED pre-fix: last hashed evidence = stale green hash ≠ post-rewrite disk bytes | GREEN: last subject-hash evidence (the refresh entry) equals the on-disk sha256 |
| A-1430-3 | green-first characterization pin (the refusal exists today) — pinned byte-identical | GREEN pre- and post-fix: `issue #1036` + basis/current hashes + `--re-certify` remedy |
| U-1430-1 | RED pre-fix: no `refresh` cycle entry, no covering-scope witness | GREEN: refresh entry carries the post-rewrite hash; the scoped re-proof names `test/a1_test.dart` (the covering-test witness) |
| U-1430-2 | green-first pin (misfire path) | GREEN: build-pass misfire → exit non-zero, zero refresh entries |
| U-1430-3 | green-first pin (byte-equality) | GREEN: clean pass appends only the no-op refactor entry; zero refresh entries |
| U-1430-4 | green-first pin (pending subject) | GREEN: rewritten pending subject → no refresh entry |
| U-1430-5 | RED pre-fix: no per-behavior refresh entries | GREEN: one refresh entry per touched certified behavior, hashes match disk |
| U-1430-6 | green-first pins (freshness vacuous pre-writer) | GREEN 6a/6b: stale-refresh and hash-mismatch drifts refuse; 6c: #1162 fail-open unchanged; 6d: born-green refusal stands |

Final suite state: `dart test --preset=all
test/plugins/tdd/bug_1430_refresh_evidence_test.dart` → **12/12 passed**
(10m07s wall, real `dart test` children). `dart analyze lib/src/plugins/tdd/
test/plugins/tdd/` → no issues. `dart format` clean.

## Phase 2 — Test smells

- No test interdependence: every test builds its own hermetic fixture
  (`TddFixture.create` + `dispose`).
- No assertion-free tests: every behavior asserts an observable output
  (exit code, stdout contract lines, cycle-log fields parsed via
  `CycleEvidence.entries()`).
- No time bombs / ordering coupling: hand-seeded evidence uses fixed
  ISO-8601 timestamps; the freshness pins use explicit early/late dates.
- Helpers (`seedCertifiedGreen`, `seedHashedEvidence`) mirror the existing
  fixture conventions; no copy-paste drift detected.

## Phase 3 — Deliberate mutant (the profile's fallback sampling)

**Mutant M1** (the riskiest new logic — the guard's freshness gate):
`refreshedAt.isAfter(basisAt)` dropped from `_subjectDriftRefusal`.

Result: **killed** — U-1430-6a flips red immediately (`outcome=skipped`
wrongly replaces the refusal for a refresh older than the live green).
Reverted; `dart analyze` clean after revert.

## Phase 4 — Acceptance-criteria coverage

- FR-001 → A-1430-1, A-1430-2 (resume clean, evidence↔disk agreement)
- FR-002 → U-1430-1 (witness scope), U-1430-4 (certified-only refresh)
- FR-003 → A-1430-3, U-1430-6a/6b (out-of-band drift still refuses)
- FR-004 → U-1430-2 (no green-washing on failure paths)
- FR-005 → U-1430-3 (byte-equality), U-1430-4 (no surprise writes)
- FR-006 → shape = evidence refresh (research D1); #1162/#1331 neighbors
  pinned by U-1430-6c/6d
- SC-001 → A-1430-1; SC-002 → A-1430-3 + 6a/6b; SC-003 → U-1430-2;
  SC-004 → 12/12 suite + fast-tier neighbor sweeps green

## Scope note (honest gaps)

- The heavyweight whole-suite E2E files (`make_command_test.dart`,
  `two_cycle_run_commands_test.dart`) were not run to completion in this
  session (operator time-box); the targeted seam suites
  (`make_command_1036_test.dart`, `refactor_command_test.dart`) and the
  fast-tier guard/cycle-log neighbors were run — results recorded in the
  final report. The diff is additive (a new consult + a new append on the
  success path only); the intermediate forced-full scope change that could
  have perturbed existing flows was removed before this audit.
- Mutation coverage is the rubric's single-deliberate-mutant sample, not a
  full campaign (no mutation tool wired, per the tdd-profile).
