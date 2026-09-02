// Integration test for `zfa tdd fake <channel>` (issue #831 —
// platform-channel test harness, certified fakes).
//
// RED reproduction contract: the command does not exist today. When it
// does, it must (1) write the committed-intent scenario script under
// `specs/<feature>/tdd/scenarios/`, (2) write the test-side certified
// fake that registers a handler via TestDefaultBinaryMessengerBinding,
// (3) keep an already-committed scenario (never silently overwrite
// intent), and (4) print a machine-readable summary line.
library;

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory tmpDir;
  const featureName = '013-barcode-fixture';

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('fake_command_test_');
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  Directory seedSpec() {
    final dir = Directory(p.join(tmpDir.path, 'specs', featureName, 'tdd'))
      ..createSync(recursive: true);
    File(p.join(dir.parent.path, 'spec.md')).writeAsStringSync('''
# Spec for barcode fixture

## Success Criteria

- **SC-001**: barcode scan replays a scripted result
''');
    return dir;
  }

  List<String> fakeArgs(List<String> extra) => [
    'tdd',
    'fake',
    '--project',
    tmpDir.path,
    '--feature',
    featureName,
    ...extra,
  ];

  group('zfa tdd fake writes the certified pair (issue #831)', () {
    test(
      'emitted fake + committed scenario are syntactically valid Dart/JSON',
      () async {
        seedSpec();
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing(
          fakeArgs([
            'dev.zuraffa/barcode',
            '--behavior',
            'T1',
            '--platforms',
            'ios,android',
          ]),
        );
        final fakePath = p.join(
          tmpDir.path,
          'test',
          'tdd',
          featureName,
          'fakes',
          't1_fake.dart',
        );
        // Template escaping is the classic failure mode of generated code:
        // the emitted fake must PARSE cleanly (channel names with quotes,
        // backslashes, slashes, etc.).
        final result = parseString(
          content: File(fakePath).readAsStringSync(),
          path: fakePath,
          throwIfDiagnostics: false,
        );
        // parseString reports parse-level diagnostics only (no resolution),
        // so a clean template escaping job yields an EMPTY list.
        expect(
          result.errors,
          isEmpty,
          reason: result.errors.map((e) => e.message).join('\n'),
        );
      },
    );

    test('writes scenario JSON + fake dart, bound to a behavior id', () async {
      seedSpec();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        fakeArgs([
          'dev.zuraffa/barcode',
          '--behavior',
          'T1',
          '--platforms',
          'ios,android',
        ]),
      );

      // Machine-readable summary line (house convention: final line).
      expect(out, contains('channel=dev.zuraffa/barcode'));
      expect(out, contains('feature=$featureName'));
      expect(out, contains('platforms=ios,android'));

      final scenarioPath = p.join(
        tmpDir.path,
        'specs',
        featureName,
        'tdd',
        'scenarios',
        't1.json',
      );
      final fakePath = p.join(
        tmpDir.path,
        'test',
        'tdd',
        featureName,
        'fakes',
        't1_fake.dart',
      );
      expect(File(scenarioPath).existsSync(), isTrue, reason: scenarioPath);
      expect(File(fakePath).existsSync(), isTrue, reason: fakePath);

      // Scenario: committed intent, machine-parseable, channel-bound.
      final scenarioContent = File(scenarioPath).readAsStringSync();
      expect(scenarioContent, contains('"channel": "dev.zuraffa/barcode"'));
      final scenarioJson = jsonDecode(scenarioContent) as Map<String, Object?>;
      expect(scenarioJson['platforms'], ['ios', 'android']);
      expect(
        scenarioJson,
        contains('default'),
        reason: 'unscripted methods must fail loudly (required default)',
      );

      // Fake: a framework-certified test-side handler — registered via
      // TestDefaultBinaryMessengerBinding, replaying the scenario,
      // recording observed calls (arguments + order). NOT an
      // agent-written mock: responses come from the scenario file.
      final fakeContent = File(fakePath).readAsStringSync();
      expect(
        fakeContent,
        contains('TestDefaultBinaryMessengerBinding'),
        reason: 'the harness contract names the binding explicitly',
      );
      expect(fakeContent, contains("MethodChannel('dev.zuraffa/barcode')"));
      expect(fakeContent, contains('setMockMethodCallHandler'));
      expect(fakeContent, contains('recordedCalls'));
      expect(fakeContent, contains('T1Fake'));
      expect(fakeContent, contains('class RecordedChannelCall'));
      // Provenance: generated by the fake command, names its scenario.
      expect(fakeContent, contains('// GENERATED FAKE'));
      expect(fakeContent, contains('t1.json'));
    });

    test('summary line names the scenario + fake paths', () async {
      seedSpec();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        fakeArgs(['app.camera', '--behavior', 'T1']),
      );
      expect(
        out,
        contains('scenario=specs/$featureName/tdd/scenarios/t1.json'),
      );
      expect(out, contains('fake=test/tdd/$featureName/fakes/t1_fake.dart'));
      // No platforms declared → empty matrix, still valid.
      expect(out, contains('platforms='));
    });

    test('re-run keeps the committed scenario, regenerates the fake', () async {
      seedSpec();
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(fakeArgs(['app.camera', '--behavior', 'T1']));

      final scenarioPath = p.join(
        tmpDir.path,
        'specs',
        featureName,
        'tdd',
        'scenarios',
        't1.json',
      );
      // Simulate the human committing intent: edit the scenario.
      File(scenarioPath).writeAsStringSync('''
{
  "channel": "app.camera",
  "platforms": ["macos"],
  "responses": {
    "available": {"value": false}
  },
  "default": {"error": {"code": "unscripted", "message": "nope"}}
}
''');
      final out = await runner.runCapturing(
        fakeArgs(['app.camera', '--behavior', 'T1']),
      );
      // Intent survives: no silent overwrite without --force.
      expect(File(scenarioPath).readAsStringSync(), contains('"available"'));
      expect(File(scenarioPath).readAsStringSync(), contains('macos'));
      expect(out.toLowerCase(), contains('scenario kept'));
    });

    test('--force rewrites the scenario starter', () async {
      seedSpec();
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(fakeArgs(['app.camera', '--behavior', 'T1']));
      final scenarioPath = p.join(
        tmpDir.path,
        'specs',
        featureName,
        'tdd',
        'scenarios',
        't1.json',
      );
      final before = File(scenarioPath).readAsStringSync();
      final out = await runner.runCapturing(
        fakeArgs(['app.camera', '--behavior', 'T1', '--force']),
      );
      expect(out.toLowerCase(), contains('scenario rewritten'));
      expect(File(scenarioPath).readAsStringSync(), sameStarterAs(before));
    });

    test('unknown platform token is refused before any write', () async {
      seedSpec();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing(
        fakeArgs(['app.camera', '--behavior', 'T1', '--platforms', 'fuchsia']),
      );
      expect(out.toLowerCase(), contains('unknown platform'));
      final scenarioPath = p.join(
        tmpDir.path,
        'specs',
        featureName,
        'tdd',
        'scenarios',
        't1.json',
      );
      expect(File(scenarioPath).existsSync(), isFalse);
    });

    test('missing --feature is a usage error (intent needs a home)', () async {
      seedSpec();
      final runner = CliRunner(exitOnCompletion: false);
      final out = await runner.runCapturing([
        'tdd',
        'fake',
        '--project',
        tmpDir.path,
        'app.camera',
      ]);
      expect(out.toLowerCase(), contains('--feature'));
    });
  });
}

Matcher sameStarterAs(String expected) => _SameStarterAs(expected);

class _SameStarterAs extends Matcher {
  _SameStarterAs(this.expected);
  final String expected;

  @override
  bool matches(Object? item, Map<dynamic, dynamic> matchState) {
    if (item is! String) return false;
    // The starter is deterministic: re-running --force reproduces the
    // same committed-intent skeleton (idempotent generation).
    return item.trim() == expected.trim();
  }

  @override
  Description describe(Description description) =>
      description.add('matches the deterministic scenario starter');
}
