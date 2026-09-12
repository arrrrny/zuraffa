**Template Version**: `zuraffa-1.0`

# Spec: 1518-gen-guard-warning-pre-1483-remedy

## Summary

PR #1502 (issue #1483) branched the RUN driver's vacuous-green stop remedy by
feature shape (`vacuousGuardFallbackRemedyFor` in `vacuous_guard.dart`): a
lane-split feature hand-edits the lane plan's traces cell, a legacy
single-file feature (no `## Lanes`, no `04-ENGINE.md` on disk and never one)
hand-edits the test list's traces cell. The #1308 GEN-TIME guard-only warning
was deliberately NOT touched — and it still prints the pre-#1483 advice. The
writer's warning hardcodes the bare `04-ENGINE.md` wording
(`vacuousGuardFallbackRemedy`), and `_forwardGuardOnlyWarning` forwards those
lines into the run transcript. In ONE transcript the author sees the WRONG
remedy first (gen warning → nonexistent `04-ENGINE.md`) and the RIGHT remedy
second (the stop → the test-list traces cell) — two contradictory
`--> fix:` lines naming two different seams. This feature branches the
gen-time warning's remedy by feature shape — the writer resolves the seam
from disk exactly like the run side — and retires the pre-#1483 constant so
one branched wording family serves gen, the writer, and the run driver.

## Acceptance Scenarios

1. **Given** a LEGACY single-file feature (no lane plan pair on disk) whose
   gen emits a guard-only unit test for a fallback-routed behavior **When**
   the run transcript is read (the gen child's forwarded warning AND the
   later vacuous-green make stop) **Then** BOTH `--> fix:` lines name the
   SAME seam — `hand-edit the test list (specs/<feature>/tdd/test-list.md)
   traces cell to FR-00N, Row.method` — and NEITHER line names the
   nonexistent `04-ENGINE.md` (the contradiction is unreachable).
2. **Given** a LANE-SPLIT feature (`tdd/04-ENGINE.md` on disk; the orphan
   `tdd/04-SKIN.md` shape likewise) **When** the gen-time guard-only warning
   fires **Then** the remedy names the lane plan's traces cell with the full
   path — the same seam the run-side stop names — never the test list.
3. **Given** the run driver forwards the gen child's captured output
   **When** the writer's warning is the BRANCHED wording (no longer a fixed
   constant) **Then** the forwarding scan still forwards the warning token
   line AND the `--> fix:` remedy line that immediately follows it — and
   still forwards nothing else (the scan stays surgical; a stray
   `--> fix:` line not preceded by the token line is not forwarded).
4. **Given** the pre-#1483 constant `vacuousGuardFallbackRemedy` is retired
   **When** the pinned suites are run (#1320 U8, the #1483 shape suite
   U-1483-1c, the #1308 vocabulary suite U-1308-1) **Then** every pin has
   been migrated to the branched `vacuousGuardFallbackRemedyFor` wording IN
   THE SAME CHANGE and the suites pass — the wording family (the re-plan/
   re-gen/re-run advice, the `FR-00N, Row.method` hand-delta cell, the
   `the designed hand-delta seam` tail) stays one.
5. **Given** the run-side stop remedy, the vacuous-green detection, the stop
   machine contract, and the loop semantics **When** the suite runs **Then**
   they are unchanged (messaging-only: `stopped_at=<id>:make` preserved, the
   generated test shape unchanged, `make`'s refusal unchanged), and the
   staleness-mirror render inside gen prints the SAME branched warning as
   the real write (one wording per transcript, no new drift surface).

## Functional Requirements

- **FR-001**: The gen-time guard-only warning (`behavior_test_writer.dart`)
  MUST prescribe the seam that EXISTS for the feature shape it is talking
  to, resolved from disk exactly like the run-side seam resolution: the
  engine plan (`tdd/04-ENGINE.md`) when present, else the skin plan
  (`tdd/04-SKIN.md`) when present, else the test list
  (`tdd/test-list.md`) — printed with the FULL path relative to the project
  root, through the shared `vacuousGuardFallbackRemedyFor` builder. The
  writer carries the seam context (project root + feature dir) provided by
  gen; WITHOUT the context (direct library use) it prescribes the
  conservative legacy single-file branch: the canonical
  `specs/<feature>/tdd/test-list.md` path derived from the behavior.
- **FR-002**: The run driver's forwarding of the gen child's guard-only
  warning (`run_driver_core.dart` `_forwardGuardOnlyWarning`) MUST key on
  the `zfa:tdd: guard-only` token line and forward the `--> fix:` remedy
  line that immediately follows it — the remedy text itself can no longer
  be a scan key (it is branched). The scan MUST stay surgical: token lines
  and their remedy line only, never a dump of the captured output.
- **FR-003**: The pre-#1483 shared constant `vacuousGuardFallbackRemedy` is
  RETIRED. The branched `vacuousGuardFallbackRemedyFor` is the ONE remedy
  wording source. Every suite that pinned the constant byte-exactly or by
  substring (the #1320 suite's U8, the #1483 shape suite's U-1483-1c, the
  #1308 vocabulary suite's U-1308-1, and the #1308 writer warning suite's
  U-1308-2) MUST be migrated to the branched builder in the same change.
- **FR-004**: The gen command threads the seam context (project root, feature
  dir) into the writer for BOTH the real write AND the staleness-mirror
  render, so every warning printed by one gen invocation carries the same
  branched wording.
- **FR-005**: Hard constraints preserved: messaging-only — no
  detection/stop/loop changes; the `stopped_at=<id>:make` machine contract
  is preserved; the generated test shape is unchanged; the run-side stop
  remedy (`_vacuousFallbackRemedy`) behavior is unchanged; `dart analyze`
  reports no new warnings.

## Success Criteria

- **SC-1**: In a legacy single-file feature's run transcript, the forwarded
  gen warning's `--> fix:` line and the vacuous-green stop's `--> fix:` line
  name the same test-list seam (grep-able), and neither contains
  `04-ENGINE`.
- **SC-2**: The writer's warning over a lane-split feature names the lane
  plan path; over the orphan skin shape names `04-SKIN.md`; over a
  no-context direct write names the canonical
  `specs/<feature>/tdd/test-list.md`.
- **SC-3**: The forwarding scan forwards the token line + the following
  remedy line over the writer's REAL printed output (round-trip), and a
  stray `--> fix:` line without a preceding token line stays unforwarded.
- **SC-4**: The migrated pin suites (#1320 U8, #1483 fast U-1483-1c,
  #1308 U-1308-1/U-1308-2) pass against the branched builder; the
  #1483 driver suites (U-1483-2/3/4) and the #1308 driver suite
  (U-1308-4/5) pass unchanged (the run side is untouched).
- **SC-5**: `dart analyze` over the changed files reports no new issues
  versus the pristine-HEAD baseline.
