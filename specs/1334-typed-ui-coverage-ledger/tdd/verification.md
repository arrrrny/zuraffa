# TDD Verification: 1334-typed-ui-coverage-ledger (issue #1143)

**Suite scope (cloud agent budget — only what this change touches, never the
full suite):** `test/tdd/1334-typed-ui-coverage-ledger/` (8), `test/tdd/0966-typed-ledger-rows/`
(8, regression — 3 subjects updated to the five-kind contract), `test/tdd/075-ui-coverage-ledger/`
(22, regression — the legacy pipeline this feature must not break).

## Test-first evidence (red → green, recorded in `tdd/evidence/`)

| behavior | red (pre-implementation) | green (post-implementation) |
| -------- | ------------------------ | --------------------------- |
| T1 five kinds + golden advisory | `t001-red.txt` — compile fail: `LedgerRowKind.isGoldenScenario` missing; the shipped vocabulary has a sixth `golden` kind | `t001-green.txt` — +1 passed |
| T2 per-screen all-five-kinds report | `t002-red.txt` — compile fail: `kindCoverageAllKinds` / `ScreenKindReport` / `ScreenTraceStatus` / `groupByScreen` missing | `t002-green.txt` — +1 passed |
| T3 per-screen gate | `t003-red.txt` — compile fail: `TypedCoverageGate.evaluateScreens` / `TypedScreensVerdict` missing | `t003-green.txt` — +1 passed |
| T4 per-kind overlay rendering | `t004-red.txt` — compile fail: `XrayLedgerOverlay.renderScreen` / `renderByScreen` / `XrayLedgerDeck.screenEntries` missing | `t004-green.txt` — +1 passed |
| T5 plan-time kinds verbatim | `t005-red.txt` — compile fail: `DeclaredLedgerRow.screen` / `advisory` plan-time seam missing | `t005-green.txt` — +1 passed |
| T6 legacy mode | `t006-red.txt` — compile fail: `TypedLedgerBuilder.fromLedgerJson` / `LedgerParseResult` / `TypedCoverageVerdict.legacy` missing | `t006-green.txt` — +1 passed (strengthened post-audit with the golden-only 0966-artifact pin; re-recorded green) |
| T7 strength pins | `t007-red.txt` — compile fail: `zeroTraced` / report APIs missing | `t007-green.txt` — +1 passed |
| T8 artifact pins | `t008-red.txt` — compile fail: screens-verdict APIs missing | `t008-green.txt` — the verification record itself |

All red runs are the REAL transcripts captured before any production code was
written (the subjects compile against APIs that did not exist; T1's file also
shows the vocabulary pin failing against the six-kind enum). No step is claimed
that was not run.

## ACTUAL final results (this session, the deliverable runs)

| check | command | result |
| ----- | ------- | ------ |
| 1334 suite | `dart test test/tdd/1334-typed-ui-coverage-ledger/` | `00:00 +8: All tests passed!` — 8/8 PASS |
| 0966 regression | `dart test test/tdd/0966-typed-ledger-rows/` | `00:00 +8: All tests passed!` — 8/8 PASS |
| 075 regression | `dart test test/tdd/075-ui-coverage-ledger/` | `00:02 +22: All tests passed!` — 22/22 PASS |
| analyze | `dart analyze` (all changed files) | 0 errors, 0 warnings; 16 info-level `non_constant_identifier_names` — the same lint class every 075/0966 self-hosting subject carries (CI: `--no-fatal-warnings`) — PASS |
| format | `dart format --set-exit-if-changed lib test` (the CI gate) | `Formatted 2458 files (0 changed)` — PASS |
| disk | `df -h .` | 17% used — healthy; `.dart_tool/test/` kernel cache removed after every phase |

Unrelated pre-existing findings: full-tree `dart format .` (wider than the CI
gate's `lib test` scope) would reformat 3 PRE-EXISTING drifted files
(`corpus/regression/*/u1_test.dart` ×2, `specs/1256-*/tdd/red_repro.dart`) —
committed before this branch, outside this change set, outside the CI format
gate; reverted here, not shipped in the PR.

## Mutation evidence (the deliberate-audit strength answer)

`tdd/evidence/deliberate-mutation-report.md` — 10 mutants over the #1143
production seams (`typed_ledger_row.dart` + `xray_ledger_binding.dart`),
per-mutant scope = the 1334 + 0966 subject suites (18 tests):

| result | count | mutants |
| ------ | ----- | ------- |
| KILLED | 9 | M1 zeroTraced predicate · M2 legacy classifier · M3 status polarity · M4 plan-time advisory flag · M5 per-screen gate kind gaps · M6 HIGHLIGHT marker · M7 0966-golden reclassification (killed after the T6 strengthening pass) · M8 six-kind vocabulary · M9 undeclared-kind skipping |
| SURVIVED (equivalent, documented) | 1 | M10 — the feature-wide verdict's `legacy ||` arm: `unproven == 0` implies every declared kind has a traced row, so the arm is unreachable; kept as defensive documentation of AC-6 |

The first audit run found M7 surviving (the 0966-golden seam was underpinned) —
the honest remedy was a NEW pin, not a shrug: T6 gained the golden-only
0966-artifact case (`kind: 'golden'`, no advisory field, no other typed row →
typed, advisory forced), and M7 died on the re-run. Post-restore sanity run:
GREEN.

## Success criteria — PROVED vs not

| # | criterion | status | evidence |
| - | --------- | ------ | -------- |
| S1 | five kinds exactly | **PROVED** | T1/T7 enumeration + order pins; M8 killed |
| S2 | presence-only screen not 100% | **PROVED** | T2 (presence 9/9 + four 0/0 gaps, `partially-traced`); T3 (gate fails, 4 failure lines); M1/M9 killed |
| S3 | honest five-kind screen passes | **PROVED** | T2/T3 (`fully-traced`, aggregate passed) |
| S4 | golden advisory | **PROVED** | T1 (presence + advisory + tolerance; gate passes with golden red; deck ADVISORY); M4 killed |
| S5 | per-kind overlay rendering | **PROVED** | T4 (status + per-kind lines, HIGHLIGHT, no surface names; legacy paint kept for kindless ledgers); M6 killed |
| S6 | plan-time kinds verbatim | **PROVED** | T5 (verb matrix + explicit-kind rows survive derivation; screen rides through) |
| S7 | legacy mode | **PROVED** | T6 (075 JSON → presence + legacy; all-green passes; one-red fails on row gap only; verdict-shape JSON; 0966-golden reads typed); M2/M7 killed |
| S8 | no regressions | **PROVED** | 0966 8/8 + 075 22/22 green after the golden-kind reclassification; analyze/format clean |

All 8 success criteria PROVED by tests that were red first and green after —
none asserted without a run.
