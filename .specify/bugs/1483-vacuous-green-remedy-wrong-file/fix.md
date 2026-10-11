# Bug Fix: the vacuous-green remedy is branched by feature shape and names an existing seam

- **Slug**: 1483-vacuous-green-remedy-wrong-file
- **Fixed**: 2026-09-10
- **Assessment**: ./assessment.md
- **Test**: ./test.md
- **Status**: applied
- **TDD artifacts**: `tdd/test-list.md`, `tdd/verification.md` (this directory) — red-green evidence from the real driver-level run.

## Summary

The vacuous-green make stop now names the seam that EXISTS for the feature
shape it is talking to. A lane-split feature (the lane plan pair on disk)
keeps the issue #1320 lane-plan remedy; a legacy single-file feature (no
`## Lanes`, no plan pair — the shape `zfa tdd plan` produces with no lane
split) is told to hand-edit the TEST LIST's traces cell instead of the
nonexistent `04-ENGINE.md`. Both branches print the full path of the file
to edit (relative to the project root), because a bare filename hides the
feature dir. The fix is messaging-only per the issue's hard constraints:
the vacuous-green detection, the stop result, the
`stopped_at=<id>:make` machine contract and the loop semantics are
untouched.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/vacuous_guard.dart` | added `vacuousGuardFallbackRemedyFor({required String? lanePlanPath, required String testListPath})` | One wording family with the #1308/#1320 constant: the re-plan/re-gen/re-run advice and the `FR-00N, Row.method` hand-delta cell stay verbatim; only the seam noun + path branch (`lane plan (<path>)` vs `test list (<path>)`). The pre-#1483 constant `vacuousGuardFallbackRemedy` is UNCHANGED — the gen-time writer, the run transcript forwarding scan and the #1320 suite pin it byte-exactly. |
| `lib/src/plugins/tdd/commands/run_driver_core.dart` | the fallback vacuous-green arm prints the branched remedy via the new private helper `_vacuousFallbackRemedy({projectRoot, featureDir})` | Seam detection is the lane plan pair on disk: `tdd/04-ENGINE.md` exists → the engine plan is the seam; else `tdd/04-SKIN.md` exists → the skin plan; else → the test list (the legacy single-file shape). Paths are `p.relative(..., from: projectRoot)` — the full path of the file to edit. A stale `split-receipt.json` without plan files deliberately stays single-file: with no meta-index plan pair, rows (and their traces cells) resolve from the test list itself. |
| `test/plugins/tdd/bug_1483_vacuous_green_remedy_shape_test.dart` | added (fast tier) | 3 tests: the single-file branch, the lane-split branch, and the shared-constant pin. |
| `test/plugins/tdd/bug_1483_vacuous_green_remedy_driver_test.dart` | added (slow tier) | 2 driver tests over the REAL `RunDriverCore` + scripted fake zfa: the legacy single-file stop and the lane-split stop. |

## Diff highlights

The branch, at the stop site (messaging only — the surrounding state
advance, receipt and return are byte-identical):

```dart
// Issue #1483: name the seam that EXISTS for the feature shape
// the message is talking to — the lane plan's traces cell only
// when the lane plan pair is actually on disk; the legacy
// single-file feature (no `## Lanes`, no plan pair) hand-edits
// the TEST LIST's traces cell instead (04-ENGINE.md does not
// exist there and never will). The full path is printed (the
// feature dir is not obvious from a bare filename). Messaging
// only — the detection, the stop and the loop are untouched.
print('   --> fix: ${_vacuousFallbackRemedy(projectRoot: projectRoot, featureDir: featureDir)}');
```

The vocabulary branch:

```dart
String vacuousGuardFallbackRemedyFor({
  required String? lanePlanPath,
  required String testListPath,
}) {
  final seamPath = lanePlanPath ?? testListPath;
  final seamNoun = lanePlanPath != null ? 'lane plan' : 'test list';
  return 'add traces: <ContractRow> to the FR, re-run zfa tdd plan, '
      're-run zfa tdd gen, re-run zfa tdd run — or hand-edit the '
      '$seamNoun ($seamPath) traces cell to FR-00N, Row.method and '
      're-run zfa tdd gen (the designed hand-delta seam)';
}
```

## What did NOT change (constraint compliance)

- `contentIsVacuousGreen`, the marker predicate, and every detection path
  in `vacuous_guard.dart` are untouched.
- The stop arm's state advance, `result: 'stopped'`,
  `stoppedAt: '<id>:make'`, exit code and journal writes are untouched.
- `vacuousGuardFallbackRemedy` (the shared constant) is byte-identical —
  `behavior_test_writer.dart`'s gen-time warning and
  `_forwardGuardOnlyWarning`'s scan are untouched.
- The gen-time warning surface (out of the issue's scoped locations:
  `vacuous_guard.dart` / run driver) keeps the shared constant
  intentionally; see assessment, Risks.
