@Tags(['e2e'])
// Issue #2011 — `verify-red --re-certify` still cannot rebind a sole-test
// file when the recorded name is the id-less scenario description (#1778
// residual).
//
// The #1778 rebind has two gates in `_rebindRunnableTestNameIfNeeded`:
//   1. the sole-test fallback — requires the RECORDED name to carry the
//      behavior id (`recorded.contains(record.behaviorId)`); and
//   2. the id-based binding — runs only when the file holds MORE THAN ONE
//      title (`titles.length > 1`).
//
// A per-behavior test file holds exactly ONE test. When the recorded
// `runnable_test_name` carries the id-less scenario description (the
// pre-#871 shape) while the on-disk title is the corrected id-prefixed
// form, gate 1 refuses (the description carries no id) and gate 2 never
// runs (one title) — so the lone title that DOES carry the id is never
// considered and the command answers `test-name-mismatch`, whose own
// remedy (`--re-certify`) is the command that just failed: the
// unsatisfiable-recovery shape #1778 was filed for.
//
// Contract under test (issue #2011): the id-carrying evidence the
// multi-test branch trusts must also admit the sole-test case — when the
// file's single title carries the behavior id, rebind to it.
//
// Slow-shape suite: spawns real `dart test` subprocesses in throwaway
// fixture projects (the #1162 file's harness), tagged `e2e` per
// dart_test.yaml (honest under direct invocation, excluded from CI's
// fast lane, 8x ceiling).
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

/// The recorded description segment (issue #2011's shape): the long
/// scenario prose with NO behavior id in it — a pre-#871 record whose
/// `runnable_test_name` is `<file>::U9::The search data layer MUST …`.
const recordedScenarioDescription =
    'The search data layer MUST expose both seams through a repository '
    'SearchRepository, whose implementation is owned by the data source';

/// The corrected on-disk title (issue #2011's shape): the short
/// id-prefixed form the #871 render writes. Carries the id, so it is
/// unambiguous — and it shares no containment with the recorded prose.
const correctedTitle =
    'U9 — the repository drives one provider query with the term, limit '
    'and offset, returning a SearchPage, and delegates the persistence '
    'seam to the data source';

/// A subject-driven test whose SOLE test title is [title] (the corrected
/// id-prefixed form) — fails on the throwing stub, passes on the real
/// implementation (the honest red -> green pair, the gen shape).
String soleTestWithCorrectedTitle(String id, String title) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
import '../lib/${id.toLowerCase().replaceAll('-', '_')}_subject.dart';
import 'package:test/test.dart';

void main() {
  test('$title', () {
    final Object? result = (() {
      try {
        return $symbol();
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, equals(42));
  });
}
''';
}

/// The gen-shaped THROWING subject stub (`zfa tdd gen <id>`).
String throwingSubject(String id) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
// GENERATED STUB — `zfa tdd gen $id`.
library;

/// Scenario runner for behavior $id.
///
/// Throws [UnimplementedError] until the real implementation lands.
int $symbol() => throw UnimplementedError('$symbol not implemented');
''';
}

/// A HAND IMPLEMENTATION (the #1162 sanctioned state): real logic, not a
/// pipeline scaffold shape.
String handImplementedSubject(String id) {
  final symbol = '${id.toLowerCase().replaceAll('-', '_')}_value';
  return '''
// Hand-implemented per the paired test header's instruction.
library;

int $symbol() {
  final base = 40;
  final step = 2;
  return base + step;
}
''';
}

List<String> verifyRedArgs2011(
  TddFixture fx,
  String id, {
  bool reCertify = false,
}) => [
  'tdd',
  'verify-red',
  '--project',
  fx.root.path,
  if (reCertify) '--re-certify',
  id,
];

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });
  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('issue 2011: sole-test rebind when the recorded name is the id-less '
      'scenario description', () {
    test('A-2011a: --re-certify rebinds the recorded name to the sole '
        'id-prefixed title and completes the re-certification', () async {
      await fx.seedCertifiedRed(
        id: 'U9',
        description: recordedScenarioDescription,
        testContent: soleTestWithCorrectedTitle('U9', correctedTitle),
        subjectContent: throwingSubject('U9'),
      );
      // Hand-implement the subject — the #1162 state --re-certify exists
      // for; the sole test now genuinely passes.
      await File(
        fx.subjectPathOf('U9'),
      ).writeAsString(handImplementedSubject('U9'));
      final runner = CliRunner(exitOnCompletion: false);

      final out = await runner.runCapturing(
        verifyRedArgs2011(fx, 'U9', reCertify: true),
      );

      expect(
        CliRunner.lastDispatchedExitCode,
        0,
        reason:
            'the prescribed remedy must not be the command that just '
            'failed: $out',
      );
      expect(out, contains('classification=re-certified'));
      expect(out, contains('certified=true'));
      // The rebind is named in the output.
      expect(out, contains('rebind: runnable_test_name updated'));
      // The registry record is rebound to the corrected title.
      final record = await fx.registryRecordOf('U9');
      expect(
        record['runnable_test_name'],
        equals('test/u9_test.dart::U9::$correctedTitle'),
      );
      // The green evidence is appended (the transition completed).
      final cycleLog = await File(fx.cycleLogPath).readAsString();
      expect(cycleLog, contains('## Cycle: U9 (green)'));
    });

    test('A-2011b: plain verify-red rebinds the sole id-prefixed title and '
        'certifies the honest red', () async {
      await fx.registerBehavior(
        id: 'U9',
        description: recordedScenarioDescription,
        testContent: soleTestWithCorrectedTitle('U9', correctedTitle),
      );
      // registerBehavior writes no subject — seed the throwing stub the
      // honest red fails on.
      final subjectFile = File(fx.subjectPathOf('U9'));
      await subjectFile.parent.create(recursive: true);
      await subjectFile.writeAsString(throwingSubject('U9'));
      final runner = CliRunner(exitOnCompletion: false);

      final out = await runner.runCapturing(verifyRedArgs2011(fx, 'U9'));

      expect(
        CliRunner.lastDispatchedExitCode,
        0,
        reason:
            'the id-carrying sole title is unambiguous red evidence: '
            '$out',
      );
      expect(out, contains('classification=assertion'));
      expect(out, contains('certified=true'));
      expect(out, contains('rebind: runnable_test_name updated'));
      final record = await fx.registryRecordOf('U9');
      expect(
        record['runnable_test_name'],
        equals('test/u9_test.dart::U9::$correctedTitle'),
      );
    });
  });
}
