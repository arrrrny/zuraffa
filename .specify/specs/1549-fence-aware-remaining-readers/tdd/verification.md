# TDD Verification — Spec 1549 (fence-aware cycle-log splitting in the three remaining line-scanner readers)

- **Feature**: `1549-fence-aware-remaining-readers` (issue #1549 — route
  `provenance_scanner`, `ci_referee/failure_artifacts`,
  `ci_referee/feature_provenance_reader` through the fence-aware splitter)
- **Generated**: FRESH from the actual run in this session (2026-09-13) —
  not a copy of a prior verification.
- **Command path**: `/speckit.specify` → `/speckit.plan` → `/speckit.tasks`
  → `/speckit.analyze` (cross-artifact drift check: PR #1543 found unmerged
  on master → helper VENDORED byte-identical, hard constraint added to the
  spec) → `/speckit.tdd.plan` → `/speckit.tdd.run` (red → green, evidence
  logs recorded) → `/speckit.implement` → this audit.
- **Scope note**: the three readers' body-level field semantics are
  unchanged; only the section source changed (fence-aware entry-sections
  iterator instead of fence-blind `## Cycle:` line matching).
  `cycle_evidence.dart`'s naive splits are PR #1543's scope — untouched.

## Verdict: **PASSED** (red → green recorded; 81 targeted tests + downstream consumers green; analyze at baseline)

| Gate | Result |
|------|--------|
| Preflight (baseline) | ✅ `dart pub get` clean; repo baseline `dart analyze` = 112 pre-existing infos, 0 errors/warnings |
| Vendored helper contract | ✅ `test/plugins/tdd/services/cycle_log_sections_test.dart` → **12/12 pass**, file BYTE-IDENTICAL to `origin/fix/cycle-log-phantom-sections` (staged via `git checkout <branch> -- <paths>`, no edits) |
| Test-first evidence | ✅ red log captured with the readers NOT yet converted (`tdd/red-1549.log`, exit 1, `+21 -3`) |
| Red-phase evidence | ✅ 3 failures, one per reader, each for the RIGHT reason — see §1 |
| Iterator red → green | ✅ iterator test written first → load error (library absent); implemented → **7/7 pass** |
| Green | ✅ `tdd/green-1549.log` — exit 0, `+24: All tests passed!` (21 pre-existing + 3 fixtures) |
| Downstream consumers | ✅ 81/81: provenance_scanner + both vendored/new iterator suites + `cycle_evidence_test` + `cycle_log_test` + ALL 7 `ci_referee/` suites + `referee_command_test` + `corpus_audit_command_test`; re-run post-format: 75/75 |
| Acceptance-criteria coverage | ✅ SC-1→R1, SC-2→R3, SC-3→R5, SC-4→U1–U6+V1, SC-5→R2/R4/R6 (existing suites unmodified), SC-6→this gate table (see §4) |
| `dart analyze` (changed files) | ✅ "No issues found!" on all 10 changed files; repo-wide re-run = 112 issues — EXACTLY the pre-existing baseline, 0 new warnings |
| `dart format` | ✅ `Formatted 2753 files (0 changed)` after the initial pass normalized the 4 touched test files |

## 1. Test-first evidence (this session, branch `feat/1549-fence-aware-remaining-readers`)

Order of operations, before any reader implementation existed:

1. Vendored `cycle_log_sections.dart` + its test from PR #1543's branch
   (byte-identical, git-staged) → 12/12 green — the shared splitter is
   load-bearing on this branch because PR #1543 is NOT yet merged.
2. Wrote `cycle_log_entry_sections_test.dart` (7 behaviors) FIRST →
   load error (library absent) → implemented
   `cycle_log_entry_sections.dart` (`CycleLogEntrySection` +
   `parseCycleLogEntrySections`) → 7/7 green.
3. Wrote the three reader fixtures (one in-fence `## Cycle:` scenario per
   reader) and ran the three suites against the UNCONVERTED readers:
   **exit 1, `+21 -3`** — recorded in `tdd/red-1549.log`:
   - `provenance_scanner_test.dart · U26 (1549)`: `lib/src/phantom.dart`
     WAS attributed (the phantom `(refactor)` header flipped
     `inRefactorSection` and the in-fence `changed:` line became an
     attribution) — expected `isNull`, SC-1.
   - `failure_artifacts_test.dart · 1549`: excerpt truncated at the
     in-fence `## Cycle:` banner (`closeEntry()` fired early);
     `failingLine` fell back to `Expected: <42>` instead of the post-banner
     frame `f_fence_test.dart:18` — SC-2.
   - `feature_provenance_reader_test.dart · 1549`: state came back
     `realizing` instead of `completeReal` — the in-fence
     `## Cycle: PHANTOM (green)` header stole the following
     `- kind: green`, so `B-020` lacked green evidence — SC-3.

## 2. Red → green (cycle log)

- Converted the three readers to iterate
  `parseCycleLogEntrySections()` (built on the vendored splitter):
  - `provenance_scanner.dart` `_collectRefactorAttributions`:
    `inRefactorSection = entry.kind == 'refactor'` per section;
    `currentCommand` hoisted outside the entry loop (cross-entry
    persistence preserved, as before).
  - `ci_referee/failure_artifacts.dart` `_parseRedEntries`: skip
    non-`red` entries; per-entry `currentTest`/`inOutput`/`output` state;
    emission at entry end replaces the header-driven `closeEntry()`.
  - `ci_referee/feature_provenance_reader.dart` `_readGreenBehaviors`:
    `greens.add(entry.behavior)` from the section header; body
    `- kind:` grammar unchanged.
- Re-ran the same three suites: **exit 0, `+24: All tests passed!`**
  (`tdd/green-1549.log`).
- Sanity: the fixtures' phantom expectations are now satisfied by
  construction — an in-fence `## ` line cannot start a section, so no
  scanner state can flip, no excerpt can close early, and no phantom
  header can set `currentBehavior`.

## 3. Non-behavioural verification

- `dart analyze` on all 10 changed files: **No issues found!**
- Repo-wide `dart analyze`: **112 issues** — byte-identical count to the
  pre-change baseline (all pre-existing infos elsewhere in the tree).
- `dart format` on the changed files, then a full-tree
  `--set-exit-if-changed` pass: **0 changed across 2753 files**.
- Post-format re-run of the targeted + downstream set: **75/75 pass**.
- Hard constraints held: helper files byte-identical (add/add
  auto-resolves when either PR merges); `cycle_evidence.dart` untouched;
  no model/writer changes; the existing U25–U30, A11–A13, U1–U6 suites
  passed unmodified (SC-5).

## 4. Acceptance-criteria coverage

| Criterion | Evidence |
|---|---|
| SC-1 (phantom never attributes; real refactor still does) | R1 — `provenance_scanner_test.dart::an in-fence Cycle line never flips refactor attribution (1549)`; regression U25–U30 |
| SC-2 (one artifact, full excerpt, post-banner failing frame, banner verbatim) | R3 — `failure_artifacts_test.dart::an in-fence Cycle line never truncates the red excerpt (1549)`; regression A11–A13 |
| SC-3 (phantom never greens; real green completes the feature) | R5 — `feature_provenance_reader_test.dart::an in-fence Cycle line never greens a phantom behavior (1549)`; regression U1–U6 |
| SC-4 (all three readers route through the splitter; no fence-blind sectioning remains) | U1–U6 (iterator unit behaviors) + V1 (vendored splitter suite) + the three converted readers (§2) |
| SC-5 (well-formed-log output unchanged) | R2/R4/R6 — the three readers' existing suites pass UNMODIFIED (21 pre-existing tests green in both the red and green runs) |
| SC-6 (no new analyze warnings; format clean) | §3 gate rows |
