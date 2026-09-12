// Bug #1518 — the gen-time guard-only warning must prescribe the seam that
// EXISTS for the feature shape it is talking to (the #1483 branch, gen side).
//
// PR #1502 branched the RUN driver's vacuous-green stop remedy by feature
// shape (`vacuousGuardFallbackRemedyFor`): a lane-split feature hand-edits
// the lane plan's traces cell, a legacy single-file feature (no `## Lanes`)
// hand-edits the TEST LIST's traces cell. The #1308 gen-time warning was
// deliberately not touched — it still prints the pre-#1483 advice with the
// lane plan hardcoded as a bare `04-ENGINE.md`, a file that does not exist
// for a legacy single-file feature and never will. `_forwardGuardOnlyWarning`
// forwards those lines into the run transcript, so ONE transcript carries
// the WRONG remedy first (gen warning) and the RIGHT remedy second (the
// stop) — two contradictory `--> fix:` lines. The remediation is
// messaging-only:
//
//   1. the writer's warning resolves the seam from disk exactly like the
//      run side (engine plan → skin plan → test list, full path) through
//      the SAME branched builder; the no-context direct-library case
//      prescribes the conservative feature-derived test-list branch;
//   2. the forwarding scan keys on the TOKEN line and forwards the
//      `--> fix:` line that immediately follows it (the branched remedy
//      text can no longer be a scan key);
//   3. the pre-#1483 constant is RETIRED — the branched builder is the one
//      wording source, and every pin migrates in the same change
//      (bug_1320 U8, bug_1483 U-1483-1c, issue_1308 U-1308-1/U-1308-2).
//
// Test map (fast tier — the driver-level transcript proof lives in
// bug_1518_gen_guard_warning_forward_driver_test.dart):
//   U-1518-1 — legacy single-file shape: the warning names the test-list
//            traces cell (full path), never 04-ENGINE.
//   U-1518-2 — lane-split shape: the warning names the lane plan traces
//            cell (full path), never the test list.
//   U-1518-3 — orphan skin shape: the warning names the skin plan.
//   U-1518-4 — no seam context: the conservative feature-derived
//            test-list branch.
//   U-1518-5 — the forwarding scanner round-trips the writer's REAL
//            printed warning (token line + branched fix line), handles a
//            two-behavior double warning, and leaves a stray `--> fix:`
//            line — including one that is NOT the line directly after the
//            token line — unforwarded.
library;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/behavior.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/vacuous_guard.dart';

/// Runs [body] and returns everything printed (via [ZoneSpecification.print])
/// as a single newline-joined string.
Future<String> capturePrint(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
}

/// The issue's fallback-routed shape: kind=unit, no contract shape, prose
/// heuristics unmatched — the writer emits the bare UnimplementedError guard
/// and the guard-only warning fires.
Behavior fallbackBehavior(String id, String feature) => Behavior(
  id: id,
  feature: feature,
  kind: BehaviorKind.unit,
  description: 'lets the user add a todo with a title',
  sourceCriterion: 'FR-001',
  target: 'subjectUnderTest',
);

void main() {
  late Directory tmp;
  const feature = '1518-warning-seam';

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bug_1518_fast_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    exitCode = 0;
  });

  /// The writer with the gen-provided seam context over a feature dir under
  /// [tmp], writing the fallback guard-only pair and returning the printed
  /// output plus the emitted test content.
  Future<(String, String)> writeWithSeam({
    String? engineFile,
    String? skinFile,
  }) async {
    final featureDir = p.join(tmp.path, 'specs', feature);
    final tddDir = p.join(featureDir, 'tdd');
    await Directory(tddDir).create(recursive: true);
    if (engineFile != null) {
      await File(p.join(tddDir, '04-ENGINE.md')).writeAsString(engineFile);
    }
    if (skinFile != null) {
      await File(p.join(tddDir, '04-SKIN.md')).writeAsString(skinFile);
    }
    final testPath = p.join(tmp.path, 'test', 'u1_test.dart');
    final writer = BehaviorTestWriter(
      projectRoot: tmp.path,
      featureDir: featureDir,
    );
    final printed = await capturePrint(
      () => writer.write(
        behavior: fallbackBehavior('U1', feature),
        testPath: testPath,
        subjectPath: p.join(tmp.path, 'lib', 'u1_subject.dart'),
      ),
    );
    final content = File(testPath).readAsStringSync();
    return (printed, content);
  }

  test(
    'U-1518-1: LEGACY single-file shape — the gen-time warning names the '
    'test-list traces cell (full path), never the nonexistent 04-ENGINE.md',
    () async {
      final (printed, content) = await writeWithSeam();

      // The warning still fires on the fallback guard-only shape and the
      // test file is still emitted (the #1308 contract, unchanged).
      expect(printed, contains(vacuousGuardWarningToken), reason: printed);
      expect(
        content,
        contains('expect(result, isNot(isA<UnimplementedError>()));'),
      );
      expect(contentCarriesVacuousGuardMarker(content), isFalse);

      // THE FIX: the remedy names the seam that EXISTS — the test list's
      // traces cell, with the FULL path (feature dir included).
      expect(
        printed,
        contains(
          'hand-edit the test list '
          '(${p.join('specs', feature, 'tdd', 'test-list.md')}) '
          'traces cell',
        ),
        reason: printed,
      );
      // ...and never sends the author to the nonexistent lane plan.
      expect(printed, isNot(contains('04-ENGINE')), reason: printed);
    },
  );

  test('U-1518-2: LANE-SPLIT shape — the gen-time warning names the lane plan '
      'traces cell (full path), never the test list', () async {
    final (printed, _) = await writeWithSeam(
      engineFile: '# Engine Plan: $feature\n',
    );

    expect(printed, contains(vacuousGuardWarningToken), reason: printed);
    expect(
      printed,
      contains(
        'hand-edit the lane plan '
        '(${p.join('specs', feature, 'tdd', '04-ENGINE.md')}) '
        'traces cell',
      ),
      reason: printed,
    );
    expect(printed, isNot(contains('test-list.md')), reason: printed);
  });

  test('U-1518-3: orphan SKIN shape — the gen-time warning names the skin plan '
      'traces cell (full path)', () async {
    final (printed, _) = await writeWithSeam(
      skinFile: '# Skin Plan: $feature\n',
    );

    expect(printed, contains(vacuousGuardWarningToken), reason: printed);
    expect(
      printed,
      contains(
        'hand-edit the lane plan '
        '(${p.join('specs', feature, 'tdd', '04-SKIN.md')}) '
        'traces cell',
      ),
      reason: printed,
    );
    expect(printed, isNot(contains('04-ENGINE')), reason: printed);
    expect(printed, isNot(contains('test-list.md')), reason: printed);
  });

  test('U-1518-4: no seam context (direct library use) — the conservative '
      'feature-derived test-list branch', () async {
    const noContextFeature = '1518-no-context-seam';
    final testPath = p.join(tmp.path, 'test', 'u1_test.dart');
    final writer = const BehaviorTestWriter();
    final printed = await capturePrint(
      () => writer.write(
        behavior: fallbackBehavior('U1', noContextFeature),
        testPath: testPath,
        subjectPath: p.join(tmp.path, 'lib', 'u1_subject.dart'),
      ),
    );

    expect(printed, contains(vacuousGuardWarningToken), reason: printed);
    expect(
      printed,
      contains(
        'hand-edit the test list '
        '(${p.join('specs', noContextFeature, 'tdd', 'test-list.md')}) '
        'traces cell',
      ),
      reason: printed,
    );
    expect(printed, isNot(contains('04-ENGINE')), reason: printed);
  });

  test('U-1518-5: the forwarding scanner round-trips the writer\u0027s REAL '
      'printed warning and stays surgical', () async {
    // The real printed warning over the single-file shape (U-1518-1's
    // writer): the scanner must forward exactly the token line and the
    // branched fix line that follows it.
    final (printed, _) = await writeWithSeam();
    final forwarded = guardOnlyWarningLinesToForward(printed).toList();

    expect(forwarded, hasLength(2), reason: printed);
    expect(forwarded.first, contains(vacuousGuardWarningToken));
    expect(forwarded.last, contains('--> fix:'));
    expect(
      forwarded.last,
      contains(
        'hand-edit the test list '
        '(${p.join('specs', feature, 'tdd', 'test-list.md')}) '
        'traces cell',
      ),
    );
    expect(forwarded.last, isNot(contains('04-ENGINE')));

    // A two-behavior double warning forwards both (token, fix) pairs.
    final doubleWarning = [
      'zfa tdd gen: WARNING [$vacuousGuardWarningToken] behavior "U1" — x',
      '   --> fix: first remedy',
      'zfa tdd gen: WARNING [$vacuousGuardWarningToken] behavior "U2" — x',
      '   --> fix: second remedy',
      'trailing noise',
    ].join('\n');
    final doubleForwarded = guardOnlyWarningLinesToForward(
      doubleWarning,
    ).toList();
    expect(doubleForwarded, hasLength(4));
    expect(doubleForwarded[1], contains('first remedy'));
    expect(doubleForwarded[3], contains('second remedy'));

    // A stray `--> fix:` line with NO preceding token line stays
    // unforwarded (the scan never dumps the captured output).
    final stray = [
      'step started',
      '   --> fix: not a guard-only warning',
      'step finished',
    ].join('\n');
    expect(guardOnlyWarningLinesToForward(stray), isEmpty);

    // The fix line is anchored to the line DIRECTLY after the token line:
    // a NON-adjacent `--> fix:` line (an unrelated later step's remedy —
    // `--> fix:` is a shared convention across the codebase) stays
    // unforwarded even though a token line precedes it.
    final interleaved = [
      'zfa tdd gen: WARNING [$vacuousGuardWarningToken] behavior "U1" — x',
      'some unrelated gen output line',
      '   --> fix: something else entirely',
    ].join('\n');
    final interleavedForwarded = guardOnlyWarningLinesToForward(
      interleaved,
    ).toList();
    expect(interleavedForwarded, hasLength(1), reason: interleaved);
    expect(interleavedForwarded.single, contains(vacuousGuardWarningToken));
    expect(
      interleavedForwarded.single,
      isNot(contains('--> fix:')),
      reason: interleaved,
    );
  });
}
