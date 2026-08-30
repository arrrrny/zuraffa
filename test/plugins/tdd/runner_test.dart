// Tests for the SingleTestRunner service (spec 046-tdd-verify-red,
// U11-U14 / T005, T007).
//
// These run a REAL tiny `dart test` project built by TddFixture in a temp
// directory, so the substitution/capture contract is graded against the
// actual runner, not a fake.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/red_classification.dart';
import 'package:zuraffa/src/plugins/tdd/services/red_classifier.dart';
import 'package:zuraffa/src/plugins/tdd/services/runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  late Directory prev;
  const description = 'returns 42 when invoked with no args';

  setUp(() async {
    prev = Directory.current;
    fx = await TddFixture.create();
    await fx.registerBehavior(id: 'B-001', description: description);
  });

  tearDown(() {
    Directory.current = prev;
    fx.dispose();
  });

  group('U11 — profile single template substitution', () {
    test(
      'executes exactly the target test with {file} and {name} substituted',
      () async {
        final runner = const SingleTestRunner();
        final template = await runner.loadSingleTemplate(
          workingDirectory: fx.root.path,
        );
        final record = await runner.runSingle(
          singleTemplate: template,
          testPath: fx.testPathOf('B-001'),
          testName: description,
          workingDirectory: fx.root.path,
        );
        // The resolved command embeds both substitutions.
        expect(record.command, contains(fx.testPathOf('B-001')));
        expect(record.command, contains(description));
        // And it targeted exactly one test: an honest assertion red.
        expect(record.testCount, 1);
        expect(classify(record), RedClassification.assertion);
      },
    );
  });

  group('U12 — exit code and combined output capture', () {
    test('captures the non-zero exit and the assertion text', () async {
      final runner = const SingleTestRunner();
      final record = await runner.runSingle(
        singleTemplate: TddFixture.defaultSingleTemplate,
        testPath: fx.testPathOf('B-001'),
        testName: description,
        workingDirectory: fx.root.path,
      );
      expect(record.exitCode, isNot(0));
      expect(record.output, contains('Expected:'));
      expect(record.output, contains('Actual:'));
    });

    test('captures exit 0 for a passing test', () async {
      final fx2 = await TddFixture.create();
      try {
        await fx2.registerBehavior(
          id: 'B-001',
          description: description,
          testContent: TddFixture.greenTest(description),
        );
        final runner = const SingleTestRunner();
        final record = await runner.runSingle(
          singleTemplate: TddFixture.defaultSingleTemplate,
          testPath: fx2.testPathOf('B-001'),
          testName: description,
          workingDirectory: fx2.root.path,
        );
        expect(record.exitCode, 0);
        expect(record.output, contains('All tests passed'));
      } finally {
        fx2.dispose();
      }
    });
  });

  group('U13 — failed process launch', () {
    test('records startedProcess=false when the executable cannot launch',
      () async {
        final runner = const SingleTestRunner();
        final record = await runner.runSingle(
          singleTemplate:
              'definitely_not_a_real_binary_xyz {file} --plain-name "{name}"',
          testPath: fx.testPathOf('B-001'),
          testName: description,
          workingDirectory: fx.root.path,
        );
        expect(record.startedProcess, isFalse);
        expect(classify(record), RedClassification.runnerError);
      },
    );
  });

  group('U14 — working directory', () {
    test('executes in the provided working directory', () async {
      final runner = const SingleTestRunner();
      // A path RELATIVE to the fixture root only resolves when the
      // process actually runs there.
      final record = await runner.runSingle(
        singleTemplate: TddFixture.defaultSingleTemplate,
        testPath: 'test/b_001_test.dart',
        testName: description,
        workingDirectory: fx.root.path,
      );
      // If the working directory were ignored, the file would fail to
      // load; instead exactly one test ran and failed honestly.
      expect(classify(record), RedClassification.assertion);
      expect(record.testCount, 1);
    });
  });

  group('profile loading (T005; feeds U27 misfire-stop)', () {
    test('prefers the machine-readable Keys block', () async {
      final runner = const SingleTestRunner();
      final template = await runner.loadSingleTemplate(
        workingDirectory: fx.root.path,
      );
      expect(template, TddFixture.defaultSingleTemplate);
    });

    test('falls back to the Single test bullet and normalizes <path>/<name>',
      () async {
        final fx2 = await TddFixture.create();
        try {
          final dir = Directory(
            '${fx2.root.path}/.specify/memory',
          );
          await dir.create(recursive: true);
          await File('${dir.path}/tdd-profile.md').writeAsString('''
# Profile

## Commands

- Single test: `dart test <path> --plain-name "<name>"` (substring).
''');
          final runner = const SingleTestRunner();
          final template = await runner.loadSingleTemplate(
            workingDirectory: fx2.root.path,
          );
          expect(template, 'dart test {file} --plain-name "{name}"');
        } finally {
          fx2.dispose();
        }
      },
    );

    test('misfire-stops when the profile file is missing', () async {
      final noProfileDir = Directory.systemTemp.createTempSync('no_prof_');
      try {
        final runner = const SingleTestRunner();
        expect(
          () => runner.loadSingleTemplate(workingDirectory: noProfileDir.path),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('tdd-profile.md'),
            ),
          ),
        );
      } finally {
        if (noProfileDir.existsSync()) noProfileDir.deleteSync(recursive: true);
      }
    });

    test('misfire-stops when no single template is present', () async {
      final fx2 = await TddFixture.create();
      try {
        final dir = Directory('${fx2.root.path}/.specify/memory');
        await dir.create(recursive: true);
        await File('${dir.path}/tdd-profile.md').writeAsString('''
# Profile

## Commands

- Full suite: `dart test`
''');
        final runner = const SingleTestRunner();
        expect(
          () => runner.loadSingleTemplate(workingDirectory: fx2.root.path),
          throwsA(isA<StateError>()),
        );
      } finally {
        fx2.dispose();
      }
    });
  });
}
