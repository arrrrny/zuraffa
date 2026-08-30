---
feature: 046-tdd-verify-red
verdict: FAIL
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 6b9a445a
behaviors: 41
proven: 22
likely: 0
test_after: 19
no_test: 0
high_smells: 0
criteria_total: 14
criteria_covered: 14
mutation_score: null # no mutation tool wired; 6 deliberate mutants, 6 caught, 0 survived
mutants_survived: 0
suite: 183 passed, 0 failed, 3m46s (dart test test/plugins/tdd/)
---

# TDD Verification: `zfa tdd verify-red`

**Verdict: FAIL — 19 of 41 behaviors are TEST_AFTER** (admitted in the
cycle log, cycles 5–7: the command's rejection, resolution, and
contract wiring was implemented in cycle 4's skeleton before its
dedicated tests existed). No `HIGH` smells, every acceptance criterion
is covered end to end, and all six deliberate mutants were caught — the
tests are strong; the *order* for those 19 behaviors cannot be proven.

Audit run by the same session that wrote the tests (stated per Hard
Rule 2): every file was re-read cold for this report rather than
recited from memory, and the cycle log's own admissions — not the
auditor's optimism — drive the classification.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| U1–U10 | PROVEN | cycle 2: red recorded (`Error when reading ...red_classification.dart` — module absent), tests+source same commit `c8395b26` |
| U11–U14 | PROVEN | cycle 3: red recorded (module absent), tests+source same commit `4e068329` |
| U15, U16 | PROVEN | cycle 1: assertion red recorded (`"- criterion: FR-006" must appear after the previous contract field`), tests+source same commit `bf54c605` |
| U23, U25, U27, A1–A3 | PROVEN | cycle 4: assertion red recorded against the misfire-stop stub (`Actual: '❌ Error: Bad state: zfa tdd verify-red: not yet implemented...'`), tests+source same commit `a7141b27` |
| U24, A4–A8 | TEST_AFTER | cycle 5 admission: rejection branch implemented in cycle 4; tests landed `a3d32577`, passed on first run |
| U17–U22, A9–A12 | TEST_AFTER | cycle 6: resolution logic implemented in cycle 4; tests landed `e6d6737e`. The one genuine red in that cycle (SC-004) was a test-fixture bug, not missing behavior |
| U26, A13–A14 | TEST_AFTER | cycle 7 admission: contract implemented in cycle 4; tests landed `5232a80b`, passed on first run |

Pre-existing tests: `cycle_entry_test.dart` and `cycle_log_test.dart`
(spec 041) were modified only to pass the widened constructor's new
required fields; no assertion was removed or loosened (verified by
reading the diff — 041's four original cycle-entry tests are intact
with their original expectations, plus four new ones).

## Findings

| # | Severity | Finding | Evidence |
| - | -------- | ------- | -------- |
| 1 | HIGH | 19/41 behaviors TEST_AFTER (verdict-blocking) — rejection, resolution, and contract wiring of the command landed in cycle 4 before their dedicated tests | cycle-log admissions, cycles 5–7; commits `a7141b27` < `a3d32577`/`e6d6737e`/`5232a80b` |
| 2 | MED | Subprocess-heavy suite: the feature adds ~3.5 minutes of real `dart test` child processes to `dart test test/plugins/tdd/` (183 tests, 3m46s); deterministic (pub cache warm after the host repo's `dart pub get`) but slow for a "fast tier" | `test/plugins/tdd/verify_red_command_test.dart`, `runner_test.dart`, `scenarios/*` |
| 3 | LOW | `TddFixture._fingerprint` is a length+polynomial hash, not sha256 — exact for accidental-change detection, not cryptographic | `test/plugins/tdd/helpers/tdd_fixture.dart:196` |

## Mutation results

No mutation tool is wired in CI (profile note), so deliberate mutants
were applied one at a time to the highest-risk behaviors (the ones the
acceptance criteria depend on), each restored and verified green
afterwards:

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| `red_classifier.dart` load-signature guard disabled (`if (false && ...)`) | U4, U8, U10 | No | 4 tests failed; load-vs-compile discrimination is pinned |
| `red_classifier.dart` count-guard weakened (null-only) | U7 | No | blended-run test failed; exactly-one-test guard pinned |
| `red_classifier.dart` assertion branch dropped | U1 | No | 2 tests failed; honest-red signature pinned |
| `runner.dart` substitute-then-tokenize (breaks names with spaces) | U11 | No | 4 tests failed; tokenization order pinned |
| `verify_red_command.dart` evidence written on every classification | U23, U24 | No | 7 tests failed; assertion-only evidence pinned |
| `cycle_entry.dart` criterion field dropped | U15 | No | ordered-fields test failed; 8-field shape pinned |

Sample: 6 mutants across U1, U4, U7, U8, U10, U11, U15, U23, U24 —
the highest-risk subset, not the full behavior set. Restore verified by
a final full scoped-suite run: 183 passed, 0 failed, clean tree.

## Traceability

| Criterion | Tests | End to end |
| --------- | ----- | ---------- |
| US1.AC1–AC3 | A1–A3 (`sc_001`) | Yes — real CLI, real `dart test` child |
| US2.AC1–AC5 | A4–A8 (`sc_002`) | Yes |
| US3.AC1–AC4 | A9–A12 (`sc_003`) | Yes |
| US4.AC1–AC2 | A13–A14 (`sc_004`) | Yes |
| FR-001..010 | U1–U27 (unit tiers beneath each AC) | Yes |

Untested criteria: none. Tests tracing to nothing: none. Every
acceptance criterion reaches the real entry point
(`CliRunner` → `zfa tdd verify-red` → real `dart test` subprocess), not
just units with doubles.

## What was not audited

- No mutation tool run: `mutation_test` is not wired in CI; strength
  was measured by 6 sampled deliberate mutants only, not exhaustively.
- Coverage was not run (profile marks it opt-in, not a gate).
- Repo-wide suite health is out of scope: master carries 13 pre-existing
  failures (slice/gym/parity) unrelated to this feature; this audit
  graded only `dart test test/plugins/tdd/` (green, 183/0).
- The auditor is the implementing session; the smell pass was re-read
  cold file-by-file but is not an independent fresh-context review.

## Remediation

Appended to `tasks.md` as Phase 8 (T025, T026). Finding 1 is blocking
per the rubric; it cannot be cleared retroactively (commit order is
history). Clearance path: the strength evidence above plus the next
consumer feature (`zfa tdd make`, epic 045) driving these contracts
test-first from its own loop.
