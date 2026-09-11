# Test List: 1518-gen-guard-warning-pre-1483-remedy

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1518-1 | the gen-time guard-only warning over a LEGACY single-file feature (seam context present, no lane plan pair on disk) prescribes the test-list traces cell with the full project-relative path and never names 04-ENGINE | GREEN |
| U-1518-2 | the warning over a LANE-SPLIT feature (tdd/04-ENGINE.md on disk) prescribes the lane plan traces cell (full path) and never names the test list | GREEN |
| U-1518-3 | the warning over the orphan SKIN shape (04-SKIN.md on disk, 04-ENGINE.md absent) prescribes the skin plan traces cell (full path) | GREEN |
| U-1518-4 | the warning over a direct-library write (no seam context) prescribes the conservative test-list branch with the canonical feature-derived path | GREEN |
| U-1518-5 | the forwarding scanner forwards the token line AND the branched `--> fix:` line that immediately follows it over the writer's REAL printed warning (round trip), forwards both lines of a two-behavior double warning, and leaves a stray `--> fix:` line without a preceding token line unforwarded | GREEN |
| U-1518-6 | the migrated pin suites hold: the branched builder's two outputs are pinned byte-exactly (the #1483 U-1483-1c role), the #1320 U8 wording family holds on both branches, and the #1308 vocabulary/writer assertions carry the branched wording | GREEN |
| U-1518-7 | DRIVER: a legacy single-file feature's run transcript carries the forwarded gen warning AND the vacuous-green stop with TWO AGREEING `--> fix:` lines (both name the test-list seam; neither names 04-ENGINE); `stopped_at=U1:make` preserved | GREEN |
| U-1518-REG1 | regression guard: the #1483 driver suites (the branched STOP wording over every shape), the #1308 driver forwarding suite, and the #1259 refusal suite pass unchanged — the run side and the detection are untouched | GREEN |

## Layer contracts

```yaml
# fr: FR-001
behavior_test_writer.dart: the guard-only warning's remedy resolves the seam from disk (LaneSplitFiles.engine -> LaneSplitFiles.skin -> test-list.md, relativized against projectRoot) through vacuousGuardFallbackRemedyFor; the no-context case prescribes the feature-derived test-list branch
# fr: FR-002
vacuous_guard.dart: guardOnlyWarningLinesToForward forwards the vacuousGuardWarningToken line and the --> fix: line that immediately follows it, nothing else
# fr: FR-003
vacuous_guard.dart: vacuousGuardFallbackRemedyFor is the ONE remedy wording source; the pre-#1483 constant is retired
```

## Key entities

```yaml
BehaviorTestWriter: writes the paired unit test; emits the guard-only fallback warning with the shape-branched remedy (seam context: projectRoot + featureDir)
vacuousGuardFallbackRemedyFor: the branched remedy wording builder (the one source)
guardOnlyWarningLinesToForward: the pure forwarding scanner (token-anchored)
RunDriverCore._forwardGuardOnlyWarning: echoes the scanner's lines into the run transcript
```

## External dependencies

(none — pure-Dart messaging layer; the driver suite uses the scripted fake
zfa binary from TddFixture, the issue #1308/#1483 convention)
