/// Vacuous-green detection for the UNIT and ACCEPTANCE lanes (issues
/// #1259, #1488).
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
///
/// Issue #1488: the SAME refusal covers ACCEPTANCE rows. Their paired
/// subject is a parameterless `void` scenario runner that the composition
/// lane never rewrites the test for (the 044 ownership contract), so a
/// guard-only acceptance test stays guard-only for its whole life and
/// every post-compose green it certifies is proof-free. The remedy is
/// lane-branched: the acceptance capture only ever resolves `null`, so
/// the unit-lane "assert the observable outcome at the capture" advice
/// cannot be carried out there — the acceptance branch prescribes the
/// traced re-plan/re-gen path ([vacuousGuardFallbackRemedyFor]).
///
/// Issue #1651: the SCALAR TYPE-ONLY shape joins the vacuity class. The
/// #1259 remediation replaced the bare guard with a typed assertion
/// (`expect(result, isA<int>())`) for scalar-declared contracts — but the
/// #1517 func pass fills the subject with `return 0;`, which SATISFIES a
/// type check, so the terminal dummy-body green persisted. The typed
/// emission now carries the [vacuousGuardMarker]
/// ([typeOnlyVacuousGuardComment], the entity/void branch's discipline),
/// and the content backstop strips scalar type-only expects so legacy
/// marker-less tests are refused mechanically.
///
/// Issue #1512: this module also carries the ACCEPTANCE lane's two
/// vocabulary constants ([acceptanceFallbackGuardToken] and
/// [acceptanceFallbackGuardComment]). The acceptance lane shares the
/// guard-only shape but NOT the marker discipline: its subject is a
/// parameterless `void` scenario runner whose declared outcome is
/// asserted through the composition lane, so its fallback is the
/// fallback-routed class and must keep the marker absent.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'artifact_registry.dart';
import 'born_green.dart';
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

/// Issue #1420: the remedy for the marker-absent vacuous-green stop when the
/// row's traces cell DOES resolve declared contract row(s) — the
/// [vacuousGuardFallbackRemedyFor] wording would be FALSE ("no traces" — the
/// trace exists) and IMPOSSIBLE to follow (`add traces:` / the
/// `FR-00N, Row.method` hand-delta: a Key Entity row declares no methods to
/// name). The accurate paths:
///
/// * re-run `zfa tdd gen <id>` — the regenerated pair carries the declared
///   surface (the typed entity-surface assertion, or the traced
///   [vacuousGuardMarker] when the entity is absent at gen); a stale
///   guard-only pair predating the declared-trace engagement is the #1388
///   stale-artifact class and regenerates on re-gen;
/// * or the hand step — write the assertion on the observable outcome in the
///   generated test, remove the marker if present, re-run make.
String vacuousGuardDeclaredTraceRemedyFor({
  required String behaviorId,
  required String testPath,
}) {
  return 're-run `zfa tdd gen $behaviorId` to regenerate the pair from the '
      'declared trace (the stale guard-only pair predates the '
      'declared-trace engagement, issue #1420), or write an assertion on '
      'the observable outcome in $testPath, remove the $vacuousGuardMarker '
      'marker if present, and re-run make';
}

/// Issue #1626: the exact remedy the make refusal (step 3c) and the run
/// driver's make-vacuous-green marker-absent stop print for an ACCEPTANCE
/// row — the designed HAND STEP, never the traces/re-plan/re-gen path.
///
/// Why the branch exists: the acceptance lane ignores the contract shape
/// BY DESIGN (issue #1512 — "the contract-derived shape rides ONLY the
/// plain-function pair (unit lane)"), so re-planning with `traces:` and
/// re-generating can never produce a real acceptance assertion — the
/// regenerated test stays guard-only and the #1488 gate refuses it again,
/// forever (the loop the issue measures). The path that ACTUALLY works is
/// the author hand step (issue #1411's designed flow, mirrored by the
/// repo's own fixture `bug_1488_acceptance_vacuous_green_test.dart`,
/// helper `outcomeAssertedAcceptanceTest`):
///
///   1. write an assertion on the observable outcome OUTSIDE the capture
///      in the test (the void-safe capture only ever resolves `null`, so
///      the guard-only test is the RED surface and the honest assertion
///      reaches the state the composed scenario writes — one non-guard
///      `expect` flips [contentIsVacuousGreen]);
///   2. implement the scenario runner in the subject;
///   3. add the [handStepHeader] attestation line;
///   4. certify the hand transition with `zfa tdd make <id> --born-green`.
///
/// Both file paths are printed project-relative (the author must know
/// where to edit — issue #1626 criterion 4), resolved by the ONE shared
/// [acceptanceHandStepPathsFor] rule so make's refusal and the run
/// driver's stop cannot name different files, and the attestation header
/// is rendered verbatim so the copy step is mechanical (the #1411 arm's
/// precedent). Unit/fallback rows keep [vacuousGuardFallbackRemedyFor]
/// where the traces path WORKS (issue #1626 criterion 3).
String acceptanceVacuousHandStepRemedyFor({
  required String behaviorId,
  required String testPath,
  required String subjectPath,
}) {
  return 'write an assertion on the observable outcome OUTSIDE the capture '
      'in $testPath (the guard-only test is the RED surface), implement '
      'the scenario runner in $subjectPath, add the attestation header '
      '(${handStepHeader(behaviorId)}), then run '
      '`zfa tdd make $behaviorId --born-green` — traces/re-plan/re-gen '
      'cannot produce a real acceptance assertion (the acceptance lane '
      'ignores the contract shape, issue #1512)';
}

/// Issue #1626 (review): the two file paths
/// [acceptanceVacuousHandStepRemedyFor] names — the generated test the
/// author asserts in and the subject the author implements the scenario
/// runner in — as project-relative POSIX paths.
///
/// ONE resolver shared by the two surfaces that print that remedy — make's
/// step-3c refusal (`make_command`) and the run driver's marker-absent
/// stop (`run_driver_core`) — the #1483/#1518 precedent: the WORDING is
/// single-sourced in [acceptanceVacuousHandStepRemedyFor], and the path
/// RULE must not drift either (make always holds the registry record; the
/// driver may run registry-less and probe the disk first).
///
/// [knownTestPath] / [knownSubjectPath] are the paths the caller already
/// KNOWS for the row: the artifact registry record's recorded path — the
/// single path contract gen writes, in either the portable
/// project-relative POSIX form or a machine-absolute one, both resolved by
/// [normalizeArtifactPath] (issue #1397) — else the location the caller
/// resolved on disk. A null argument (no record AND nothing on disk) falls
/// back to the conventional gen layout, so the remedy always names an
/// editable location instead of a path that need not exist.
///
/// The fail-open is the ABSENT record, not a damaged store: `findRecord`
/// returns null only when the registry FILE is missing (direct-library
/// runs, legacy fixtures). A corrupt or unreadable registry THROWS
/// (bug #1470 — a corrupt registry is not an empty one), and the callers
/// have already probed the record for the row before they print the
/// remedy (the driver's `hasGenArtifacts` probe), so no new crash surface
/// is opened here.
({String testPath, String subjectPath}) acceptanceHandStepPathsFor({
  required String behaviorId,
  required String projectRoot,
  required String feature,
  String? knownTestPath,
  String? knownSubjectPath,
}) {
  String? relPosix(String? known) => known == null
      ? null
      : p
            .relative(
              normalizeArtifactPath(projectRoot, known),
              from: projectRoot,
            )
            .replaceAll(r'\', '/');
  final snakeId = behaviorId.toLowerCase().replaceAll(
    RegExp(r'[^a-z0-9]+'),
    '_',
  );
  return (
    testPath:
        relPosix(knownTestPath) ??
        p
            .join('test', 'tdd', feature, '${snakeId}_test.dart')
            .replaceAll(r'\', '/'),
    subjectPath:
        relPosix(knownSubjectPath) ??
        p
            .join('lib', 'tdd', feature, '${snakeId}_subject.dart')
            .replaceAll(r'\', '/'),
  );
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

/// Issue #1512: the acceptance-lane sibling of
/// [vacuousGuardWarningToken] — the machine-greppable token the
/// acceptance lane's fallback-routed guard-only test carries.
///
/// The acceptance subject is a PARAMETERLESS `void <target>()` scenario
/// runner ([SubjectWriter] gen stub; `tdd wire` / `tdd compose` preserve
/// that signature) and its declared outcome is asserted through the
/// composition lane the planner routes to (`generation_planner.dart`
/// branch 3b) — so the acceptance fallback is NOT the traced hand-delta
/// seam and must NOT carry [vacuousGuardMarker]. Marker presence is the
/// run driver's `stopped_at=<id>:hand` discriminator (issue #1308,
/// `run_driver_core.dart`), and that classification prescribes an
/// assertion on the subject's return value which a void scenario runner
/// cannot carry; the honest class for this row is the fallback-routed
/// `stopped_at=<id>:make`. The token names the gap on the artifact
/// without claiming the marker's seam.
const String acceptanceFallbackGuardToken = 'zfa:tdd: acceptance-guard';

/// The comment block the acceptance fallback's guard-only test emits
/// alongside [acceptanceFallbackGuardToken], naming the lane's actual
/// remedy — the spec-052 composition lane — mirroring
/// [vacuousGuardComment].
const String acceptanceFallbackGuardComment =
    '''// $acceptanceFallbackGuardToken (issue #1512): the acceptance lane's
      // assertion set is the UnimplementedError guard ONLY. The acceptance
      // subject is a parameterless `void` scenario runner and the declared
      // outcome is asserted through the composition lane (`zfa tdd compose
      // <id> --feature <f>`), not in this test — so this is the
      // fallback-routed gap, NOT the traced hand-delta seam, and the
      // vacuous-guard marker is deliberately absent.''';

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

/// Issue #1651: the comment block the gen test template emits alongside
/// [vacuousGuardMarker] when the assertion set is the SCALAR TYPE-ONLY
/// shape — `expect(result, isA<int>())` on the declared return type,
/// called with representative arguments. The #1517 func pass fills the
/// subject with a dummy (`return 0;`) that SATISFIES a type check, so a
/// green here proves nothing about the outcome value — the same vacuity
/// class the bare guard is, and the same marker/remedy discipline
/// applies (the marker is the run driver's `stopped_at=<id>:hand`
/// discriminator).
const String typeOnlyVacuousGuardComment =
    '''// $vacuousGuardMarker (issue #1651): the assertion below checks the
      // declared return TYPE only — a func-scaffolded dummy (`return 0;`)
      // satisfies it, so a green here proves nothing about the outcome
      // value. Replace it with an assertion on the observable outcome
      // named by the behavior description (the spec's scenario values),
      // remove this marker, and re-run make.''';

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

/// Issue #1677: the declared return TYPE the first scalar type-only
/// expect in [content] checks — `int` for `expect(result, isA<int>())`.
/// Null when the content carries no scalar type-only expect (the
/// void/entity branch's guard-only shape). The run driver's make
/// vacuous-green marker-present stop keys on this to branch its
/// explanation the same way the writer's emission already discriminates
/// the branch ([behavior_test_writer] `_declaredAssertion`): a scalar
/// contract's marker-carrying test asserts the declared return TYPE
/// only — NOT the UnimplementedError guard — so the #1308 void/entity
/// wording would misdescribe it (the two paragraphs contradict each
/// other on the same screen).
String? scalarTypeOnlyDeclaredType(String content) =>
    _typeOnlyScalarExpect.firstMatch(content)?.group(1);

/// Issue #1651: the SCALAR TYPE-ONLY expects the detector also strips —
/// `expect(x, isA<T>())` with T one of the dummy-satisfiable scalar
/// types ({String, int, num, double, bool}, the `#1517` func scaffold's
/// literal set). A `return 0;` dummy satisfies a type check, so a test
/// whose assertions reduce to these proves nothing about the outcome
/// value. The capture group (issue #1677) names the declared type for
/// [scalarTypeOnlyDeclaredType]; it does not change what the detector's
/// `replaceAll` removes. Precision guards: `isNot(isA<T>())` (the second
/// argument starts with `isNot`) and `throwsA(isA<T>())` (wrapped) do
/// NOT match — both FAIL on a dummy, so both discriminate;
/// composite/generic types (`isA<List<int>>()`) and entity types (whose
/// subjects cannot be dummied — #1517 leaves the throw in place) stay
/// real.
///
/// Review of #1667: the shape also covers the hand-authored variants —
/// `expectLater(x, isA<T>())`, a trailing named argument
/// (`expect(x, isA<T>(), reason: '...')` — reason/skip/timeout are the
/// expect/expectLater named set and never change the matcher), and a
/// first argument that is any comma-free expression
/// (`expect(subject.f(), isA<T>())`). Accepted boundary: a first
/// argument containing a top-level comma (`expect(g(1, 2), isA<T>())`)
/// cannot be anchored without balanced-paren matching and stays counted
/// — the miss is conservative (a real expectation is never falsely
/// stripped; pinned as U2f).
final RegExp _typeOnlyScalarExpect = RegExp(
  r'\bexpect(?:Later)?\s*\(\s*[^,]*,\s*'
  r'isA\s*<\s*(String|int|num|double|bool)\s*>'
  r'\s*\(\s*\)'
  r'(?:\s*,\s*(?:reason|skip|timeout)\s*:\s*[^)]*)?'
  r'\s*\)\s*;?',
);

/// Every remaining expectation counts: `expect(`, `expectLater(`,
/// `expectAsync0..6`, the `fail(...)` assertion, and the flutter-test
/// `finds*` wrappers all route through an `expect`-prefixed call in the
/// generated/hand-authored corpus.
final RegExp _anyExpect = RegExp(
  r'\bexpect(?:Later|Async[0-6]?)?\s*\(|\bfail\s*\(',
);

/// Whether [content] is a vacuous-green test (issues #1259, #1488 — the
/// UNIT and ACCEPTANCE lanes): the assertion set is only the
/// UnimplementedError guard (or empty).
///
/// Two detection layers, mirroring the widget lane's `contentIsScaffolded`:
///   1. the machine-readable [vacuousGuardMarker] the gen template emits
///      with the guard-only assertion set — decisive (a stale marker
///      alongside a since-added real assertion still refuses: the remedy
///      is removing the marker, exactly like the scaffolded lane);
///   2. content-based backstop for hand-authored and legacy-generated
///      tests: strip the guard-shaped expects AND the scalar type-only
///      expects (issue #1651 — a `return 0;` dummy satisfies a type
///      check); zero remaining expectations is a vacuous assertion set.
bool contentIsVacuousGreen(String content) {
  if (content.contains(vacuousGuardMarker)) return true;
  final withoutGuards = content
      .replaceAll(_guardExpect, '')
      .replaceAll(_typeOnlyScalarExpect, '');
  return !_anyExpect.hasMatch(withoutGuards);
}

// -------------------------------------------------------------------
// Issue #1651: the TYPE-ONLY assertion class. `contentIsVacuousGreen`
// refuses guard-only tests, but the post-#1259 generated shape asserts
// the return TYPE (`expect(result, isA<int>())`) — a real expect that
// sails the guard-only gate, yet a func-scaffolded `return 0;` dummy
// satisfies it and the engine certified a terminal green. Green over a
// placeholder body requires the test to carry at least one VALUE
// assertion (the issue's bar: "at least one literal from the behavior
// description's scenario"); this detector answers "does ANY expect
// carry a value?".
// -------------------------------------------------------------------

/// Value-bearing markers inside a matcher expression: a numeric literal
/// (`equals(5)`), a quoted string (`equals('sample')`), a boolean word
/// (`equals(true)`), or a constructor call (`equals(Task(...))`). A
/// matcher with none of these asserts a TYPE or a nullability shape —
/// the placeholder-satisfiable class.
final RegExp _quotedString = RegExp("'");

/// Boundary-anchored numeric literal inside a matcher (`equals(42)`,
/// `greaterThan(0.5)`). The preceding-character check keeps `isA<Foo2>()`
/// (a type name with a digit) out of the value class.
final RegExp _numericLiteral = RegExp(r'(^|[^A-Za-z0-9_.])[0-9]');

/// Boolean literals.
final RegExp _booleanLiteral = RegExp(r'\b(true|false)\b');

/// Constructor/factory calls (`Task(`) — a constructed instance is a
/// value. `isA<X>()` does NOT match: the `(` belongs to `isA`, not to a
/// type-named constructor.
final RegExp _constructorCall = RegExp(r'[A-Z][A-Za-z0-9_]*\s*\(');

/// The declared-boolean outcome pins (`isTrue` / `isFalse`): the
/// declared-contract branch's legacy assertion for a `bool` scalar
/// outcome — the assertion the #1310 dead-end removal explicitly
/// certifies over a dummy `=> false;` body (plan_traces_cell_1310 U6).
/// They pin the DECLARED value — the twins of `equals(true)` /
/// `equals(false)` — so they are value matchers, not the type-only
/// class: the #1651 refusal is the pairing "scalar dummy body + an
/// assertion set that cannot distinguish ANY implementation", and
/// `isFalse` distinguishes `false` from everything else.
final RegExp _declaredBooleanPin = RegExp(r'\bis(?:True|False)\b');

/// The matcher argument of every `expect(`/`expectLater(` call in
/// [content]: the expression between the FIRST top-level comma and the
/// matching close paren. Comment-only lines are stripped first (the
/// generated header prose mentions assertion shapes); guard-shaped
/// expects are stripped by the same rule [contentIsVacuousGreen] uses.
List<String> _matcherExpressions(String content) {
  final codeLines = content
      .split('\n')
      .where((line) => !line.trim().startsWith('//'))
      .join('\n');
  final withoutGuards = codeLines.replaceAll(_guardExpect, '');
  final matchers = <String>[];
  final callStart = RegExp(r'\bexpect(?:Later)?\s*\(');
  for (final match in callStart.allMatches(withoutGuards)) {
    var depth = 0;
    var commaIndex = -1;
    var end = -1;
    for (var i = match.end; i < withoutGuards.length; i++) {
      final ch = withoutGuards[i];
      if (ch == '(') {
        depth++;
      } else if (ch == ')') {
        if (depth == 0) {
          end = i;
          break;
        }
        depth--;
      } else if (ch == ',' && depth == 0 && commaIndex < 0) {
        commaIndex = i;
      }
    }
    if (end < 0) continue; // unbalanced (interpolated prose) — skip
    if (commaIndex < 0) continue; // single-argument form — no matcher
    matchers.add(withoutGuards.substring(commaIndex + 1, end));
  }
  return matchers;
}

/// Whether ONE matcher expression asserts a VALUE (a literal or a
/// constructed instance) rather than a type/nullability shape.
bool _isValueMatcher(String matcher) {
  if (_quotedString.hasMatch(matcher)) return true;
  if (_numericLiteral.hasMatch(matcher)) return true;
  if (_booleanLiteral.hasMatch(matcher)) return true;
  if (_constructorCall.hasMatch(matcher)) return true;
  if (_declaredBooleanPin.hasMatch(matcher)) return true;
  return false;
}

/// Whether [content]'s assertion set is TYPE-ONLY (issue #1651): every
/// remaining expect's matcher carries no value — pure `isA<T>()` /
/// `isNotNull` / `isNot(...)` shapes, the set a scalar placeholder body
/// satisfies. The declared-boolean pins (`isTrue` / `isFalse`) are NOT
/// this class — they value-pin the declared outcome and keep the #1310
/// dead-end removal intact. False (fail-open) when no expect survives
/// the guard strip: an empty assertion set is [contentIsVacuousGreen]'s
/// class, not this one. A throwsA-shaped matcher classifies type-only,
/// but a dummy subject never throws, so the gate pairing this detector
/// with the dummy body check is unreachable there — the classification
/// only bites when the test actually PASSES on a constant body.
bool contentIsTypeOnlyAssertion(String content) {
  final matchers = _matcherExpressions(content);
  if (matchers.isEmpty) return false;
  return !matchers.any(_isValueMatcher);
}
