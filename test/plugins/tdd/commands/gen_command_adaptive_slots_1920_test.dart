/// Issue #1920 — `zfa tdd gen` threads the SKIN lane's `adaptive_slots`
/// into the generated widget test.
///
/// The conformance gate (`zfa tdd run-skin`, spec 1005) requires one
/// `skin-event: behavior=<id> slot=<slot>` line per declared slot. The
/// writer can emit that harness, but only gen knows the feature's spec:
/// these tests pin the resolution (SKIN lane membership + declared slots)
/// through the public CLI surface.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tmpDir;
  const featureName = '1920-skin-slots';
  late String featureDir;

  List<String> genArgs(String id) => [
    'tdd',
    'gen',
    '--project',
    tmpDir.path,
    id,
  ];

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('gen_skin_slots_1920_');
    featureDir = p.join(tmpDir.path, 'specs', featureName);
    final memoryDir = Directory(p.join(tmpDir.path, '.specify', 'memory'));
    memoryDir.createSync(recursive: true);
    File(p.join(memoryDir.path, 'tdd-profile.md')).writeAsStringSync('''
# TDD Profile — fixture

## Commands

- Single test: `dart test {file} --plain-name "{name}"`
- Full suite: `dart test`

## Keys (machine-readable)

```yaml
runner: dart
single: 'dart test {file} --plain-name "{name}"'
suite: 'dart test'
file: 'dart test {file}'
coverage: 'dart test --coverage'
```
''');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Future<void> seed({required String lanes, String behaviorId = 'W1'}) async {
    final specDir = Directory(featureDir);
    await specDir.create(recursive: true);
    await File(p.join(specDir.path, 'spec.md')).writeAsString('''
# Spec for $featureName

## Functional Requirements

- **SC-001**: the login view renders.

## Lanes

```yaml
Lanes:
$lanes
```
''');
    final tddDir = Directory(p.join(specDir.path, 'tdd'));
    await tddDir.create(recursive: true);
    await File(p.join(tddDir.path, 'test-list.md')).writeAsString('''
# Test List for $featureName

| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| $behaviorId | the login view renders | SC-001 | widget | PENDING | loginView |
''');
  }

  Future<String> generatedTest(String snakeId) => File(
    p.join(tmpDir.path, 'test', 'tdd', featureName, '${snakeId}_test.dart'),
  ).readAsString();

  group('issue #1920: gen resolves SKIN adaptive_slots', () {
    test(
      'a slot-declaring SKIN lane produces the slot-aware harness',
      () async {
        await seed(
          lanes:
              '  - lane: SKIN\n'
              '    behaviors: [W1]\n'
              '    flutter_allowed: true\n'
              '    adaptive_slots: [mobile, ios, android, macos]',
        );
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing(genArgs('W1'));

        final content = await generatedTest('w1');
        expect(content, contains("import 'package:flutter/foundation.dart';"));
        expect(
          content,
          contains(
            "for (final slot in const <String>['mobile', 'ios', 'android', "
            "'macos'])",
          ),
        );
        expect(
          content,
          contains("print('skin-event: behavior=W1 slot=\$slot');"),
        );
        expect(content, contains('_releaseSkinSlot(tester);'));
      },
    );

    test('a behavior outside the slot-declaring SKIN lane keeps the legacy '
        'template', () async {
      await seed(
        lanes:
            '  - lane: CORE\n'
            '    behaviors: [U1]\n'
            '    flutter_allowed: false\n'
            '  - lane: SKIN\n'
            '    behaviors: [W2]\n'
            '    flutter_allowed: true\n'
            '    adaptive_slots: [mobile, macos]',
        behaviorId: 'W1',
      );
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(genArgs('W1'));

      final content = await generatedTest('w1');
      expect(content, isNot(contains('platform:flutter/foundation.dart')));
      expect(content, isNot(contains('skin-event:')));
    });

    test('a slot-less SKIN lane keeps the legacy template', () async {
      await seed(
        lanes:
            '  - lane: SKIN\n'
            '    behaviors: [W1]\n'
            '    flutter_allowed: true',
      );
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(genArgs('W1'));

      final content = await generatedTest('w1');
      expect(content, isNot(contains('platform:flutter/foundation.dart')));
      expect(content, isNot(contains('skin-event:')));
    });
  });
}
