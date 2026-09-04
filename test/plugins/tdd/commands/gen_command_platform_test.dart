// Integration test for `zfa tdd gen` on PLATFORM-kind behaviors (issue
// #831 — platform-channel test harness).
//
// RED reproduction contract: a project whose test list declares a
// platform row must receive the platform-harness pair — a test that
// installs the certified fake (scenario-driven, registered via
// TestDefaultBinaryMessengerBinding) and asserts on the observed calls
// (arguments recorded, ordering), plus a platform-channel subject stub.
// Today gen emits the plain-function pair for such rows and knows
// nothing about scenarios — hence red.
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tmpDir;
  late String featureDir;
  const featureName = '013-barcode-fixture';

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('gen_platform_test_');
    featureDir = p.join(tmpDir.path, 'specs', featureName);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seedPlatformTestList() async {
    final specDir = Directory(featureDir);
    await specDir.create(recursive: true);
    await File(p.join(specDir.path, 'spec.md')).writeAsString('''
# Spec for barcode fixture

## Success Criteria

- **SC-001**: barcode scan result replays the scripted value
''');
    final tddDir = Directory(p.join(specDir.path, 'tdd'));
    await tddDir.create(recursive: true);
    await File(p.join(tddDir.path, 'test-list.md')).writeAsString('''
# Test List for barcode fixture

## Platform harness: channel behaviors (issue #831)

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| T1 | scans a barcode and returns the decoded payload | SC-001 | PENDING |
''');
  }

  Future<String> runFake() async {
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing([
      'tdd',
      'fake',
      '--project',
      tmpDir.path,
      '--feature',
      featureName,
      'dev.zuraffa/barcode',
      '--behavior',
      'T1',
    ]);
    return out;
  }

  List<String> genArgs(String id) => [
    'tdd',
    'gen',
    '--json',
    '--project',
    tmpDir.path,
    '--feature',
    featureName,
    id,
  ];

  test(
    'emitted platform pair parses cleanly as Dart (template escaping)',
    () async {
      await seedPlatformTestList();
      await runFake();
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(genArgs('T1'));

      final testPath = p.join(
        tmpDir.path,
        'test',
        'tdd',
        featureName,
        't1_test.dart',
      );
      final subjectPath = p.join(
        tmpDir.path,
        'lib',
        'tdd',
        featureName,
        't1_subject.dart',
      );
      for (final path in [testPath, subjectPath]) {
        final result = parseString(
          content: File(path).readAsStringSync(),
          path: path,
          throwIfDiagnostics: false,
        );
        // parseString reports parse-level diagnostics only (no
        // resolution), so clean template escaping yields an EMPTY list.
        expect(
          result.errors,
          isEmpty,
          reason: '$path\\n${result.errors.map((e) => e.message).join('\\n')}',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('gen on a platform row WITHOUT a scenario refuses honestly before any '
      'write, naming the fake command as the remedy', () async {
    await seedPlatformTestList();
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(genArgs('T1'));

    expect(out.toLowerCase(), contains('zfa tdd fake'));
    expect(out, contains('--behavior T1'));
    final testPath = p.join(
      tmpDir.path,
      'test',
      'tdd',
      featureName,
      't1_test.dart',
    );
    expect(File(testPath).existsSync(), isFalse, reason: testPath);
  }, timeout: const Timeout(Duration(minutes: 3)));

  test(
    'gen on a platform row with scenario + fake emits the platform-harness '
    'pair (fake install, observed-call assertions), not the plain pair',
    () async {
      await seedPlatformTestList();
      await runFake();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(genArgs('T1'));

      expect(out.toLowerCase(), contains('behavior_id: t1'));
      expect(out, contains('kind: platform'));
      expect(out, contains('ownership: created/created'));

      final testPath = p.join(
        tmpDir.path,
        'test',
        'tdd',
        featureName,
        't1_test.dart',
      );
      final subjectPath = p.join(
        tmpDir.path,
        'lib',
        'tdd',
        featureName,
        't1_subject.dart',
      );
      expect(File(testPath).existsSync(), isTrue, reason: testPath);
      expect(File(subjectPath).existsSync(), isTrue, reason: subjectPath);

      final testContent = File(testPath).readAsStringSync();
      // Platform harness, not the plain-function smoke lambda.
      expect(testContent, contains('TestWidgetsFlutterBinding'));
      expect(testContent, contains('T1Fake'));
      // Installs the fake and asserts on OBSERVED calls: arguments
      // recorded, ordering preserved.
      expect(testContent, contains('.install()'));
      expect(testContent, contains('recordedCalls'));
      expect(
        testContent,
        contains('invokeMethod'),
        reason: 'the certified replay drives the channel itself',
      );
      // Unscripted methods fail loudly (certified honesty).
      expect(testContent, contains('PlatformException'));
      // The plain-function assertion must NOT appear for a platform row.
      expect(
        testContent,
        isNot(contains('isNot(isA<UnimplementedError>())')),
        reason:
            'the platform harness captures the async stub error, it does '
            'not reuse the sync plain-function assertion',
      );

      final subjectContent = File(subjectPath).readAsStringSync();
      expect(subjectContent, contains("MethodChannel('dev.zuraffa/barcode')"));
      expect(subjectContent, contains('UnimplementedError'));
      expect(subjectContent, contains('subject_t1'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('gen on a platform row keeps the registry + verdict contract', () async {
    await seedPlatformTestList();
    await runFake();
    final runner = CliRunner(exitOnCompletion: false);
    final out = await runner.runCapturing(genArgs('T1'));

    final regFile = File(p.join(featureDir, 'tdd', 'artifacts.json'));
    expect(regFile.existsSync(), isTrue);
    final registry = regFile.readAsStringSync();
    expect(registry, contains('"T1"'));
    expect(registry, contains('t1_test.dart'));
    expect(registry, contains('t1_subject.dart'));

    // JSON verdict is the last stdout line (bug #840 contract).
    final lastLine = out.trim().split('\n').last;
    expect(lastLine, startsWith('{'));
    expect(lastLine, contains('"verdict"'));
    expect(lastLine, contains('"kind":"platform"'));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
