# TDD Verification — Spec 1600

**Audited**: 2026-09-13 (cold-context audit, LLM-guided — repo not zfa-wired)
**Verdict: PASS**

## Phase 1 — Test-first evidence

Source: `tdd/cycle-log.md` (appended per cycle, reds recorded before their
fixes).

| Behavior | Red evidence | Green evidence |
| -- | -- | -- |
| B1 | load-error red: `No named parameter with the name 'flutterTest'` (missing API) | C1 `+8` (writer suite included) |
| B2 | none — GUARD, proven green on the pre-fix binary FIRST, alone | C1 `+8`; golden committed from unmodified binary |
| B3 | load-error red: `Member not found: 'pubspecFor'` | C2 41 fast tests |
| B4 | load-error red: `Member not found: 'toolchainFor'` | C2 |
| B5 | load-error red: `Member not found: 'MockCertifier.forProject'` | C3 `+3` |
| B6 | same load-error red (same file) | C3 |
| B7 | compile red while the seam shape settled (probe scan) | C4 `+4` |
| B8 | same load-error red (same file) | C3 (+ capability-level degradation drive) |
| B9 | red→fix loops against the REAL Flutter toolchain (manifest conflict, pubspec regression, fixture resolution) | C5 `+3` (~7 min, Flutter 3.47.4) |
| B10 | same | C5 |

Note (recorded honestly): the test list predicted **assertion** reds for
B5/B8; the final design routes those behaviors through the new
`MockCertifier.forProject` seam, so their honest reds are missing-API
(load-error) reds — the same class #1513's writer reds used. The DEFECT
itself was reproduced end-to-end on the real binary during C5 (B9's
fixture initially reproduced the `package:test` commit; the manual dogfood
matched the issue's xzx evidence).

## Phase 2 — Test-smell rubric

- Assertions carry `reason:` strings naming the defect — no bare expects.
- No sleeps/time-based waits; process timeouts are bounded via `Timeout`.
- The golden (B2) is intentional characterization of a byte-stable public
  surface, committed as a fixture — not a snapshot-of-stdout accident.
- Fixtures are per-test temp dirs; no test-to-test coupling; tearDown
  deletes; the probe seam override restores in `finally`.
- CI-safety: the fast tier never requires the Flutter SDK (detection is
  YAML-only; toolchain execution is stubbed); the SDK-dependent proofs are
  `slow, integration`-tagged and SKIP with a reason when the SDK is absent.
- No test doubles the SUT: the stub sandbox replaces only the PROOF
  machinery, never the render/wiring under test.

No material smells.

## Phase 3 — Mutation sampling (rubric fallback; no CI mutation gate)

| Mutant | Change | Killed by | Result |
| -- | -- | -- | -- |
| M1 | `certify_mock_capability`: `MockCertifier.forProject(projectRoot)` → `MockCertifier()` (threading removed) | B8's in-process capability drive (`+3 -1` with mutant) | **killed** |
| M2 | default render drift | B2 byte-for-byte golden | **killed** (by construction; golden run pre- and post-fix) |
| M3 | `create_mock_capability`: create-side degradation check removed (`if (false)`) | B7b fast-tier capability drive (`+0 -1` with mutant) + integration degradation test | **killed** |

Restoration after each mutant verified by `cmp` against pre-mutation
backups + green re-run: `+8: All tests passed!`. **0 survived, 0 timed
out.**

## Phase 4 — Acceptance-criteria coverage

| SC | Evidence |
| -- | -- |
| SC-1 flutter-shaped import + byte-stable default | B1, B2 |
| SC-2 fixture-shaped commits (flutter vs pure-Dart) | B5, B6 |
| SC-3 live green certification + host runner passes | B9 (integration, local) |
| SC-4 manifest + toolchain selection, runner recorded | B3, B4 (+ B9 real run) |
| SC-5 no-SDK degradation; red stays red | B7, B8 (capability drive), integration degradation test, B10 |
| SC-6 certify fresh-render parity | B8 |
| SC-7 existing suites green w/o SDK; analyze clean | 165 fast mock tests; `dart analyze` on all touched lib+test files: No issues found; `dart format` applied |

## Findings carried to the PR (not remediation — the audit passes)

1. The feature REVERTS an uncommitted working-tree regression of the
   project pubspec (`test: any` as a REGULAR dependency — the exact
   issue #1189 failure mode its own comment documents). Without the
   revert, every Flutter consumer of this checkout fails `pub get`, and
   the sandbox's Flutter branch is unsolvable. Maintainer attention
   requested: the dirty pubspec predates this branch.
2. The issue's follow-up (refactor preflight distinguishing pre-existing
   broken generated tests from regressions) remains out of scope —
   #1544/#1568 family, untouched here (FR-007 respected).
3. Pre-existing observation (unchanged by this feature): `mock create
   --certify`'s CLI-level structural gate runs `dart analyze` against the
   TARGET project and needs its package config; the spec-1001 e2e fixture
   (no pubspec) predates this and is untouched.

## Gate verdict

**PASS** — TDD discipline proven (per-behavior red→green evidence), test
strength proven (3/3 sampled mutants killed, 0 survived), acceptance
criteria covered SC-1..SC-7. No remediation cycle required.
