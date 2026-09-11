/// Vacuous-green detection for the UNIT lane (issue #1259).
///
/// Bug #1259: the engine lane certified vacuous greens — a unit test
/// whose only assertion was the UnimplementedError guard
/// (`expect(result, isNot(isA<UnimplementedError>()))`) passed on any
/// non-throwing body (a func-scaffolded dummy `return 0;`), and `make`
/// certified green with zero declared-contract code anywhere in the
/// project.
///
/// Remediation (issue #1259): green certification refuses unit tests
/// whose assertion set is only the UnimplementedError guard — the
/// unit-lane analogue of the widget lane's scaffolded refusal
/// (`contentIsScaffolded`, issue #912 defect 3). The red surface can
/// START at the guard (the stub throws, the capture returns the error,
/// the guard fails — honest red), but green must require at least one
/// assertion on the observable outcome named by the behavior
/// description.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'lane_split.dart';

/// The machine-readable marker the gen test template emits when its
/// assertion set is the UnimplementedError guard only — the unit-lane
/// counterpart of the widget lane's `zfa:tdd: scaffolded` marker.
/// Greppable by the green certification and by human review.
const String vacuousGuardMarker = 'zfa:tdd: vacuous-guard';

/// The comment block the unit test template emits alongside
/// [vacuousGuardMarker], naming the exact remedy.
const String vacuousGuardComment =
    '''// $vacuousGuardMarker (issue #1259): the assertion set below is the
      // UnimplementedError guard ONLY — a green here proves nothing about
      // the behavior (a dummy `return 0;` flips it green with zero
      // declared-contract code). Replace this guard with an assertion on
      // the observable outcome named by the behavior description, remove
      // this marker, and re-run make.''';

/// Issue #1308: the exact remedy the run/stop messages and the gen-time
/// warning prescribe when the vacuous-green guard fires on a
/// FALLBACK-ROUTED behavior (no `traces:` line to a declared contract
/// row, prose heuristics unmatched — the bare-guard fall-through in
/// `behavior_test_writer.dart`'s `_deriveAssertion`). One shared wording
/// source so gen, the writer, and the run driver never drift.
///
/// Issue #1320: the remedy ALSO names the designed hand-delta seam —
/// hand-editing the lane plan's traces cell to the method-qualified
/// `FR-00N, Row.method` and re-running gen — the unlock that used to
/// exist only as tribal knowledge (plan now writes the method-qualified
/// cell itself, but the seam stays the escape hatch when a plan refuses
/// an ambiguous trace or the list is legacy).
///
/// Issue #1483: the wording became a FUNCTION, [vacuousGuardFallbackRemedyFor]
/// — the pre-#1483 form hardcoding the lane plan as a bare `04-ENGINE.md`
/// (the literal text `hand-edit the lane plan (04-ENGINE.md) traces cell`)
/// was the lane-split branch only, and sent legacy single-file authors to
/// a file that never exists. Issue #1518 retires that constant for good:
/// the branched builder below is the ONE remedy wording source (gen-time
/// warning, run stop, forwarding contract), and the pin suites (#1320 U8,
/// #1483 U-1483-1c, #1308 U-1308-1) were migrated to it in the same
/// change that retired it.
///
/// The branches:
///
/// * lane-split feature ([lanePlanPath] non-null — the lane plan pair is
///   on disk) → the lane plan's traces cell, as before;
/// * legacy single-file feature ([lanePlanPath] null) → the test list's
///   traces cell (`tdd/test-list.md`).
///
/// Both branches print the FULL path of the file to edit (the caller
/// relativizes against the project root): a bare filename hides the
/// feature dir, and the feature dir is not obvious from the stop
/// message. The wording family stays one: the re-plan/re-gen/re-run
/// advice first, the `FR-00N, Row.method` hand-delta cell, the seam tail
/// — only the seam noun + path branch.
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

/// Issue #1518: the lane-plan seam path for [featureDir] under
/// [projectRoot], or null when no lane plan pair is on disk (the test
/// list is the seam). The engine plan ([LaneSplitFiles.engine]) wins when
/// it exists, else the orphan skin plan ([LaneSplitFiles.skin]).
///
/// ONE resolver shared by the gen-time writer warning
/// (`behavior_test_writer._guardOnlyRemedy`) and the run-side stop remedy
/// (`run_driver_core._vacuousFallbackRemedy`, issue #1502) so the RULE
/// that picks the seam path cannot drift into the "two contradictory
/// `--> fix:` lines in one transcript" symptom #1518 removes — the
/// wording was single-sourced in #1483, and this closes the same gap for
/// the path probe (a new lane-plan filename, a `04-CONTRACT.md`
/// preference, a `.specify/bugs/<slug>` layout) that would otherwise have
/// to be made twice.
///
/// The returned path is project-root-relative — the full path of the file
/// to edit (a bare filename hides the feature dir).
String? lanePlanSeamPath({
  required String projectRoot,
  required String featureDir,
}) {
  final tddDir = p.join(featureDir, 'tdd');
  for (final name in [LaneSplitFiles.engine, LaneSplitFiles.skin]) {
    final plan = File(p.join(tddDir, name));
    if (plan.existsSync()) return p.relative(plan.path, from: projectRoot);
  }
  return null;
}

/// Issue #1308/#1518: the lines of the gen child's captured output that
/// the run driver forwards into the run transcript — the guard-only
/// warning token line ([vacuousGuardWarningToken]) and the `--> fix:`
/// remedy line that IMMEDIATELY follows it, nothing else (never a dump of
/// the whole captured output; a stray `--> fix:` line with no token line
/// before it stays unforwarded).
///
/// The remedy line cannot be a text scan key any more: since #1518 the
/// writer's remedy is BRANCHED by feature shape
/// ([vacuousGuardFallbackRemedyFor] — the seam path differs per feature),
/// so the forward keys on the stable two-line shape the writer prints —
/// the token line first, the remedy line directly after. The fix line is
/// accepted ONLY on the line directly after the token line: `--> fix:` is
/// a shared convention across the codebase, so a loose window would
/// forward an unrelated later line.
Iterable<String> guardOnlyWarningLinesToForward(String output) sync* {
  var expectFix = false;
  for (final line in output.split('\n')) {
    if (expectFix) {
      expectFix = false;
      if (line.contains('--> fix:')) {
        yield line;
        continue;
      }
    }
    if (line.contains(vacuousGuardWarningToken)) {
      yield line;
      expectFix = true;
    }
  }
}

/// Issue #1308: the machine-greppable token the gen-time guard-only
/// warning prints — the unit-lane sibling of [vacuousGuardMarker]. The
/// fallback path's generated test does NOT carry the marker (it is the
/// guard WITHOUT the designed seam), so the warning token is distinct:
/// the `zfa tdd run` driver scans the gen child's captured output for
/// this token and forwards the lines into the run transcript (a
/// successful gen prints nothing of its captured output otherwise, so
/// without the forward the warning would be invisible in the run).
const String vacuousGuardWarningToken = 'zfa:tdd: guard-only';

/// Whether [content] carries the machine-readable [vacuousGuardMarker] —
/// the DESIGNED hand-delta seam the traced entity/void-returning path
/// emits (issue #1259). The run driver keys on this to distinguish the
/// two vacuous-green stop classes (issue #1308): marker present → the
/// traced hand-delta seam (`stopped_at=<id>:hand`); marker absent → the
/// fallback-routed gap (the `traces:` remedy, `stopped_at=<id>:make`).
bool contentCarriesVacuousGuardMarker(String content) =>
    content.contains(vacuousGuardMarker);

/// Issue #1308: the journal violation line for the named hand step the
/// run driver records when a traced entity/void-returning behavior stops
/// vacuous-green — ONE explicit, named hand step
/// (`hand-step=<id>:hand`) telling the user exactly what to write (an
/// assertion on the observable outcome) and where (the generated test
/// file path). Rendered into the lane journal entry's violations.
String vacuousGuardHandStepViolation({
  required String behaviorId,
  required String testPath,
}) =>
    'hand-step=$behaviorId:hand — replace the $vacuousGuardMarker guard at '
    '$testPath with an assertion on the observable outcome, remove the '
    'marker, then re-run make (issue #1308)';

/// The guard-shaped expects the detector strips before counting: the
/// capture-guard the gen template emits (`expect(result,
/// isNot(isA<UnimplementedError>()))`) and the throwsA variant the
/// acceptance fixtures use (`expect(x,
/// isNot(throwsA(isA<UnimplementedError>())))`). Both prove only "the
/// subject does not throw UnimplementedError" — the issue's vacuity
/// class.
final RegExp _guardExpect = RegExp(
  r'expect\s*\(\s*[A-Za-z_][A-Za-z0-9_]*\s*,\s*'
  r'isNot\s*\(\s*(?:throwsA\s*\(\s*)?isA\s*<\s*UnimplementedError\s*>'
  r'\s*\(\s*\)\s*\)\s*\)\s*;?',
);

/// Every remaining expectation counts: `expect(`, `expectLater(`,
/// `expectAsync0..6`, the `fail(...)` assertion, and the flutter-test
/// `finds*` wrappers all route through an `expect`-prefixed call in the
/// generated/hand-authored corpus.
final RegExp _anyExpect = RegExp(
  r'\bexpect(?:Later|Async[0-6]?)?\s*\(|\bfail\s*\(',
);

/// Whether [content] is a vacuous-green UNIT test (issue #1259): the
/// assertion set is only the UnimplementedError guard (or empty).
///
/// Two detection layers, mirroring the widget lane's `contentIsScaffolded`:
///   1. the machine-readable [vacuousGuardMarker] the gen template emits
///      with the guard-only assertion set — decisive (a stale marker
///      alongside a since-added real assertion still refuses: the remedy
///      is removing the marker, exactly like the scaffolded lane);
///   2. content-based backstop for hand-authored and legacy-generated
///      tests: strip the guard-shaped expects; zero remaining
///      expectations is a vacuous assertion set.
bool contentIsVacuousGreen(String content) {
  if (content.contains(vacuousGuardMarker)) return true;
  final withoutGuards = content.replaceAll(_guardExpect, '');
  return !_anyExpect.hasMatch(withoutGuards);
}
