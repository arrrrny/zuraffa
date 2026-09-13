# TDD Verification — 1542-refactor-evidence-red-for-contract-lane

**Date**: 2026-09-13
**Branch**: `fix/1542-refactor-evidence-red-for-contract-lane` (base: master @
46fe766e)
**Toolchain**: Dart 3.13.3 (stable), spec-kit specify CLI 1.0.7.dev0 + the
repo's installed TDD extension (`.specify/extensions/tdd`, untouched)
**Result**: **PASS** — both structural dead-ends are closed with red-first
test evidence; the pinned honesty and backward-compat suites stay green
unchanged; zero new analyzer findings.

## 1. Red → green (failing-first, per spec)

RED evidence was captured BEFORE any production change (verbatim transcripts
in `tdd/cycle-log.md`; commit `94cbc555` = the red state, `2f5571f7` = the
green fix):

| order | behavior | red proof (pristine HEAD) | green proof (after fix) |
| --- | --- | --- | --- |
| 1 | U-1542-1 contract-lane green-only completes | `refactor certified but evidence for "contract:A7" is incomplete in tdd/cycle-log.md (red: false, green: true)` → `result=runner-error … stopped_at=contract:A7:refactor`, exit 2 | `result=complete`, exit 0, no misfire; verify-red skip → make green → refactor clean |
| 2 | U-1542-2 born-green journal marker completes (any lane) | same misfire for a UNIT behavior whose last green entry carries the `bornGreenEvidenceMarker` | `result=complete`; re-enters at refactor ONLY (`['refactor U1']` — make never spawns) |
| 3 | U-1542-4 full born-green contract flow | exit 2, the wedge reproduces from the post-advancement state | `result=complete`, `['refactor contract:A7']` only — no manual run-state surgery |
| 4 | M-1542-1 born-green advances run-state | `Expected: contains 'U1 blocked -> done' … Which: does not contain` — the transition certified green but left the seeded `blocked` state untouched | `run-state advanced: U1 blocked -> done (born-green certification, issue #1542)`; state file on disk flips to `done` |
| 5 | U-1542-3 / M-1542-2 / M-1542-3 (regression twins) | GREEN ON PRISTINE HEAD (pre-pass): the marker-less green-only misfire, the no-state-file no-op, the pending untouched | stay green unchanged — the twins pin the preserved contracts |

New-test totals: **7 tests** (4 driver + 3 make-level), of which 4 encode the
new behavior (red→green) and 3 are pre-passing regression twins.

## 2. Design under the hard constraints

- The refactor evidence check exempts the CLASS, not a state: contract lane
  (`BehaviorKind.contract`, the #1007 BLOCKED-never-RED lane) and
  born-green-certified (the journal probe reads the LAST green entry's
  `- evidence:` field for the shared `bornGreenEvidenceMarker`). The GREEN
  half stays mandatory for every class; the non-exempt message is
  byte-identical to the pre-#1542 one.
- The journal (not the run state) is the exemption source: the certification
  survives resets, degradations (#1468), and drops (#1264).
- `make --born-green` advances ONLY the wedged `blocked → done`; a missing
  state file is a no-op; pending/red/green/mocked/done keep their existing
  sound re-entry windows. The contract lane, the blocked verdict, and the
  state machine (`_reconcile`, `_stepsFor`, the #1007 arm) are untouched.
- The shared marker constant (`bornGreenEvidenceMarker`) is ONE wording
  source for the writer (make's append) and the reader (the driver's
  probe); it lives outside the #828 hash-chain payload, so the chain
  contract is untouched.

## 3. Suite results (REAL runs)

- `test/plugins/tdd/bug_1542_born_green_contract_refactor_test.dart`:
  **4/4 green**.
- `test/plugins/tdd/commands/bug_1411_born_green_hand_transition_test.dart`:
  **13/13 green** (B1–B7, D1–D3 unchanged + M-1542-1..3 new).
- `test/plugins/tdd/run_command_test.dart`: **50/50 green** — includes the
  PINNED bug-#682 green-only honesty misfire (the byte-identical
  `(red: false, green: true)` stop for non-exempt behaviors) and the #691/
  #694/#1324/#1331/#1345 driver contracts.
- Fast tier `test/plugins/tdd/` (+ `commands/`), chunked with kernel-cache
  cleanup between batches (disk-safe): **359 + 160 + 240 + 293 = 1,052
  green, 0 failures**.
- Slow-tagged suites re-verified individually on the changed surfaces:
  bug_1324, bug_1331, bug_1327, bug_1329, make_command_1036, bug_1430,
  bug_1162 (subject-shape), bug_1258, bug_1483 (driver + shape), bug_1264,
  subject_writer — **all green**.
- Pre-existing master failures (each VERIFIED to fail identically on
  pristine HEAD via `git stash` + re-run — NOT caused by this change):
  `bug_828_cycle_log_evidence_integrity_test.dart` (doctor `--feature`
  flag), `bug_1345_placeholder_re_drive_test.dart`,
  `bug_1162_bug_subject_green_path_test.dart` (A-1162e),
  `bug_840_recovery_commands_test.dart` (gen --adopt).

## 4. Analyzer & formatting (REAL runs)

- `dart analyze` on `lib/` + `test/plugins/tdd/`: **112 issues with the
  change vs 113 on pristine HEAD** (one FEWER — the new test's unused
  import removed); **0 errors**; zero findings in the four changed
  production files and the two changed test files.
- `dart format` on the six touched files: second run reports **0 changed**.

## 5. Acceptance-criteria coverage (spec.md SC-1..SC-5)

| SC | proven by |
| --- | --- |
| SC-1 contract-lane green-only completes | U-1542-1 (red→green) |
| SC-2 born-green journal marker accepted / twin misfires | U-1542-2 + U-1542-3 (red→green / pre-pass twin) |
| SC-3 born-green advances run-state blocked→done | M-1542-1 (+ M-1542-2/3 boundaries) |
| SC-4 full born-green contract flow completes | U-1542-4 (red→green) |
| SC-5 analyzer clean, fast tier green | §3/§4 above |
