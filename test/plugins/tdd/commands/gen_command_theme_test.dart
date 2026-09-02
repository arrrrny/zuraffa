@Tags(['slow'])
// Integration test for `zfa tdd gen` on THEME-kind behaviors (issue #841).
//
// RED reproduction contract: a project whose test list declares a theme
// row must receive the theme-harness pair (widget test asserting ShadTheme
// values + harness subject), NOT the plain-function pair.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tmpDir;
  late String featureDir;
  const featureName = '090-theme-fixture';

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('gen_theme_test_');
    featureDir = p.join(tmpDir.path, 'specs', featureName);
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seedThemeTestList() async {
    final specDir = Directory(featureDir);
    await specDir.create(recursive: true);
    await File(p.join(specDir.path, 'spec.md')).writeAsString('''
# Spec for theme fixture

## Success Criteria

- **SC-001**: brand primary asserted per mode
''');
    final tddDir = Directory(p.join(specDir.path, 'tdd'));
    await tddDir.create(recursive: true);
    await File(p.join(tddDir.path, 'test-list.md')).writeAsString('''
# Test List for theme fixture

## Theme harness: theme behaviors (issue #841)

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| T1 | pumps the shell under both ThemeModes and asserts ShadTheme brand values | SC-001 | PENDING |
''');
  }

  List<String> genArgs(String id) => [
    'tdd',
    'gen',
    '--project',
    tmpDir.path,
    '--feature',
    featureName,
    id,
  ];

  test(
    'gen on a theme row emits the theme-harness pair (ShadTheme '
    'assertions, audit, goldens, latency — not the plain-function pair)',
    () async {
      await seedThemeTestList();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(genArgs('T1'));

      expect(out.toLowerCase(), contains('behavior_id: t1'));
      expect(out, contains('ownership: created/created'));

      final testPath = p.join(tmpDir.path, 'test', 'tdd', 't1_test.dart');
      final subjectPath = p.join(tmpDir.path, 'lib', 'tdd', 't1_subject.dart');
      expect(File(testPath).existsSync(), isTrue, reason: testPath);
      expect(File(subjectPath).existsSync(), isTrue, reason: subjectPath);

      final testContent = File(testPath).readAsStringSync();
      // Theme harness, not the plain-function smoke lambda.
      expect(testContent, contains('ThemeMode.light'));
      expect(testContent, contains('ThemeMode.dark'));
      expect(testContent, contains('ShadTheme.of'));
      expect(testContent, contains('matchesGoldenFile'));
      expect(testContent, contains('parseString'));
      // The plain-function assertion must NOT appear for a theme behavior.
      expect(testContent, isNot(contains('isNot(isA<UnimplementedError>())')));

      final subjectContent = File(subjectPath).readAsStringSync();
      expect(subjectContent, contains('appShellFor(ThemeMode mode)'));
      expect(subjectContent, contains('themeHarnessSpec()'));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('gen on a theme row keeps the registry + verdict contract', () async {
    await seedThemeTestList();
    final runner = CliRunner(exitOnCompletion: false);
    await runner.runCapturing(genArgs('T1'));

    final regFile = File(p.join(featureDir, 'tdd', 'artifacts.json'));
    expect(regFile.existsSync(), isTrue);
    final registry = regFile.readAsStringSync();
    expect(registry, contains('"T1"'));
    expect(registry, contains('t1_test.dart'));
    expect(registry, contains('t1_subject.dart'));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
