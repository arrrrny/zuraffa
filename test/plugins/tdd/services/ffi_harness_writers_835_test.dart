// Bug #835 (tdd-ffi-ocr-harness): the two gen writers grow ffi branches.
//
// The SUBJECT becomes a binding-contract harness (declared contract
// constants + the three seams the generated tests assert through, all
// UnimplementedError until wired), and the TEST becomes the binding
// contract lane — ONE test named exactly `<id> — <description>` (so the
// registered runnable name matches under `--plain-name` and verify-red's
// exactly-one-test contract holds) asserting symbols-resolve +
// marshalling-round-trip with the seams captured into assertions.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/tdd_plugin.dart';
import 'package:zuraffa/src/plugins/tdd/services/behavior_test_writer.dart';
import 'package:zuraffa/src/plugins/tdd/services/subject_writer.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('ffi_writers_835_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Behavior ffiBehavior({
    String id = 'U1',
    String description =
        'the pdf-to-markdown ffi binding converts a sample pdf to markdown',
  }) => Behavior(
    id: id,
    feature: '090-ffi-fixture',
    kind: BehaviorKind.ffi,
    description: description,
    sourceCriterion: 'FR-001',
    target: 'subject_u1',
  );

  group('bug 835: the ffi subject harness', () {
    test('declares the contract constants and the three seams', () {
      final content = const SubjectWriter().render(ffiBehavior());
      expect(content, contains('const String kNativeLibrary'));
      expect(content, contains('kRequiredSymbols'));
      expect(content, contains('bool symbolResolved(String symbol)'));
      expect(content, contains('String roundTrip(String payload)'));
      expect(content, contains('String convertGolden(String input)'));
    });

    test('every seam is an UnimplementedError stub (honest red, FR-010)', () {
      final content = const SubjectWriter().render(ffiBehavior());
      final seamCount = RegExp(
        r'(bool symbolResolved|String roundTrip|String convertGolden)',
      ).allMatches(content).length;
      expect(seamCount, 3);
      expect(
        RegExp(r'=>\s*throw UnimplementedError').allMatches(content).length,
        3,
        reason: 'all three seams throw until the production binding is wired',
      );
    });

    test('carries the provenance header with the ffi kind marker', () {
      final content = const SubjectWriter().render(ffiBehavior());
      expect(content, contains('// GENERATED STUB'));
      expect(content, contains('// behavior_id: U1'));
      expect(content, contains('// kind: ffi'));
    });

    test('imports dart:ffi nowhere (compiles everywhere the loop runs)', () {
      final content = const SubjectWriter().render(ffiBehavior());
      expect(
        content,
        isNot(contains("import 'dart:ffi'")),
        reason: 'no dart:ffi import (prose mentions are fine)',
      );
    });
  });

  group('bug 835: the ffi contract test', () {
    test('names the single runnable test exactly `<id> — <description>`', () {
      final b = ffiBehavior();
      final testPath = p.join(
        tmpDir.path,
        'test',
        'tdd',
        '090-ffi-fixture',
        'u1_test.dart',
      );
      final subjectPath = p.join(
        tmpDir.path,
        'lib',
        'tdd',
        '090-ffi-fixture',
        'u1_subject.dart',
      );
      final content = const BehaviorTestWriter().renderContractTest(
        b,
        testPath,
        subjectPath,
      );
      // The registered runnable name is `<id> — <description>`; the test
      // title must contain it verbatim so --plain-name matches.
      expect(
        content,
        contains("test('U1 \u2014 ${b.description}'"),
        reason:
            'verify-red runs the registered single test by name; a '
            'different title matches zero tests and certifies runner-error',
      );
      expect(
        RegExp(r"^\s*test\(", multiLine: true).allMatches(content),
        hasLength(1),
        reason: 'exactly ONE test in the file (FR-005 exactly-one contract)',
      );
    });

    test('asserts symbols resolve and the payload round-trips', () {
      final content = const BehaviorTestWriter().renderContractTest(
        ffiBehavior(),
        p.join(tmpDir.path, 't.dart'),
        p.join(tmpDir.path, 's.dart'),
      );
      expect(content, contains('subject.kRequiredSymbols'));
      expect(content, contains('subject.symbolResolved(symbol)'));
      expect(content, contains('subject.roundTrip(payload)'));
      expect(content, contains('equals(payload)'));
    });

    test(
      'captures UnimplementedError into assertions (never a skip/error)',
      () {
        final content = const BehaviorTestWriter().renderContractTest(
          ffiBehavior(),
          p.join(tmpDir.path, 't.dart'),
          p.join(tmpDir.path, 's.dart'),
        );
        expect(content, contains('on UnimplementedError catch (error)'));
        expect(
          content,
          isNot(contains('skip:')),
          reason: 'never skipped silently (bug #835 remediation 2)',
        );
      },
    );

    test(
      'carries no tier tag (the contract lane runs in the default tier)',
      () {
        final content = const BehaviorTestWriter().renderContractTest(
          ffiBehavior(),
          p.join(tmpDir.path, 't.dart'),
          p.join(tmpDir.path, 's.dart'),
        );
        expect(
          content,
          isNot(contains('@Tags(')),
          reason: 'the loop gates on the contract lane in every default run',
        );
      },
    );
  });
}
