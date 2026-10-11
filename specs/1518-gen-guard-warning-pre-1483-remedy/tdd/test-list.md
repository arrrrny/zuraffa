# Test List: 1518-gen-guard-warning-pre-1483-remedy

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1518-1 | the gen-time guard-only warning over a LEGACY single-file feature (seam context present, no lane plan pair on disk) prescribes the test-list traces cell with the full project-relative path and never names 04-ENGINE | GREEN |
| U-1518-2 | the warning over a LANE-SPLIT feature (tdd/04-ENGINE.md on disk) prescribes the lane plan traces cell (full path) and never names the test list | GREEN |
| U-1518-3 | the warning over the orphan SKIN shape (04-SKIN.md on disk, 04-ENGINE.md absent) prescribes the skin plan traces cell (full path) | GREEN |
| U-1518-4 | the warning over a direct-library write (no seam context) prescribes the conservative test-list branch with the canonical feature-derived path | GREEN |
| U-1518-5 | the forwarding scanner forwards the token line AND the branched `--> fix:` line that immediately follows it over the writer's REAL printed warning (round trip), forwards both lines of a two-behavior double warning, and leaves a stray `--> fix:` line unforwarded — including a `--> fix:` line that is NOT the line directly after the token line (the shared-convention false positive) | GREEN |
| U-1518-6 | the migrated pin suites hold: the branched builder's two outputs are pinned byte-exactly (the #1483 U-1483-1c role), the #1320 U8 wording family holds on both branches, and the #1308 vocabulary/writer assertions carry the branched wording | GREEN |
| U-1518-7 | DRIVER: a legacy single-file feature's run transcript carries the forwarded gen warning AND the vacuous-green stop with TWO AGREEING `--> fix:` lines (both name the test-list seam; neither names 04-ENGINE); `stopped_at=U1:make` preserved | GREEN |
| G-1518-1 | CLI: the REAL `zfa tdd gen` over a legacy single-file feature prints the warning's `--> fix:` line with the test-list traces cell and never names 04-ENGINE | GREEN |
| G-1518-2 | CLI/FR-004: the REAL `zfa tdd gen` over a lane-split feature prints the lane-plan traces cell from the gen-threaded seam context, and the reused staleness mirror (`_regenerateStaleStub`) prints the SAME wording — deleting the threading collapses both to the test-list branch (mutation-verified) | GREEN |
| U-1518-REG1 | regression guard: the #1483 driver suites (the branched STOP wording over every shape), the #1308 driver forwarding suite, and the #1259 refusal suite pass unchanged — the run side and the detection are untouched | GREEN |

## Layer contracts

```yaml
# fr: FR-001
behavior_test_writer.dart: the guard-only warning's remedy resolves the seam from disk through the shared `lanePlanSeamPath` resolver (LaneSplitFiles.engine -> LaneSplitFiles.skin -> test-list.md, relativized against projectRoot) and the `vacuousGuardFallbackRemedyFor` wording; the no-context case prescribes the feature-derived test-list branch
# fr: FR-002
vacuous_guard.dart: guardOnlyWarningLinesToForward forwards the vacuousGuardWarningToken line and the --> fix: line on the line DIRECTLY after it, nothing else
# fr: FR-003
vacuous_guard.dart: vacuousGuardFallbackRemedyFor is the ONE remedy wording source; the pre-#1483 constant is retired
# fr: FR-004
vacuous_guard.dart: lanePlanSeamPath is the ONE seam-resolution rule shared by the gen-time writer warning and the run-side stop remedy; gen threads its result through _writersFor (real write) and _regenerateStaleStub (staleness mirror)
```

## Key entities

```yaml
BehaviorTestWriter: writes the paired unit test; emits the guard-only fallback warning with the shape-branched remedy (seam context: projectRoot + featureDir)
vacuousGuardFallbackRemedyFor: the branched remedy wording builder (the one source)
lanePlanSeamPath: the one seam-resolution rule (engine plan -> skin plan -> null(test list)) shared by the gen-time writer warning and the run-side stop remedy
guardOnlyWarningLinesToForward: the pure forwarding scanner (token-anchored, adjacency-enforced)
RunDriverCore._forwardGuardOnlyWarning: echoes the scanner's lines into the run transcript
```

## External dependencies

(none — pure-Dart messaging layer; the driver suite uses the scripted fake
zfa binary from TddFixture, the issue #1308/#1483 convention)
