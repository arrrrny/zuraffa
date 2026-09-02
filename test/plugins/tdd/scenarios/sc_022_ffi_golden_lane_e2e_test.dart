@Tags(['slow', 'integration', 'ffi'])
// sc_022 — Bug #835 (tdd-ffi-ocr-harness) end-to-end on the REAL CLI.
//
// The full native-boundary lifecycle, no fakes for the zfa steps:
//
//   1. a hand-written `## Native loop` row declares the ffi behavior;
//   2. `zfa tdd gen U1` emits the contract pair + the marked golden
//      fixture lane + the golden fixtures (real pdf);
//   3. `zfa tdd verify-red U1` certifies the HONEST red
//      (classification=assertion);
//   4. `zfa tdd make U1` refuses honestly (outcome=unexpressible) —
//      native work has no generator surface; the loop defers;
//   5. the default tier runs the contract lane ONLY (the golden lane is
//      excluded by the generated dart_test.yaml) and is red;
//   6. wiring the production binding (in-memory stand-in) + recording
//      the golden output flips BOTH lanes green:
//      `dart test` green, `dart test --preset=integration` green.
//
// CI wiring: this test carries the `ffi` tag — the ci.yaml
// `ffi_golden_lane` job runs `dart test --tags ffi`, so the harness that
// generates the lane is itself gated by CI (and the job can never go
// vacuously green: a zero-match tag run exits 79).
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Absolute path to the zuraffa repo root (the real zfa CLI source).
String _findZuraffaRoot() {
  var dir = Directory.current;
  while (true) {
    final pubspec = File(p.join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() &&
        pubspec.readAsStringSync().contains('name: zuraffa')) {
      return dir.path;
    }
    if (dir.path == dir.parent.path) {
      throw StateError('cannot locate the zuraffa repo root');
    }
    dir = dir.parent;
  }
}

Future<ProcessResult> _runRealZfa(
  String repoRoot,
  List<String> args, {
  required String workingDirectory,
}) {
  return Process.run(Platform.resolvedExecutable, [
    p.join(repoRoot, 'bin', 'zfa.dart'),
    ...args,
  ], workingDirectory: workingDirectory);
}

Future<ProcessResult> _runDart(
  List<String> args, {
  required String workingDirectory,
}) {
  return Process.run(
    Platform.resolvedExecutable,
    args,
    workingDirectory: workingDirectory,
  );
}

/// The dart_test.yaml content the consuming project needs for the lane
/// semantics (the same shape DartTestYamlWriter emits for fresh
/// projects): slow excluded by default, integration preset re-includes.
const _fixtureDartTestYaml = '''
tags:
  slow:
  integration:

exclude_tags: slow

presets:
  integration:
    include_tags: integration
    exclude_tags: "false"
''';

void main() {
  late Directory fx;
  late String repoRoot;
  final featureName = '091-ffi-ocr';

  Future<ProcessResult> zfa(List<String> args) => _runRealZfa(repoRoot, [
    'tdd',
    ...args,
    '--project',
    fx.path,
    '--feature',
    featureName,
  ], workingDirectory: fx.path);

  setUpAll(() async {
    repoRoot = _findZuraffaRoot();
    fx = Directory.systemTemp.createTempSync('sc_022_ffi_');
    await File(p.join(fx.path, 'pubspec.yaml')).writeAsString('''
name: tdd_fixture
environment:
  sdk: ^3.11.0
dev_dependencies:
  test: ^1.25.0
''');
    await Directory(p.join(fx.path, 'bin')).create(recursive: true);
    await File(
      p.join(fx.path, 'bin', 'zfa.dart'),
    ).writeAsString('void main() {}\n');
    await Directory(
      p.join(fx.path, '.specify', 'memory'),
    ).create(recursive: true);
    await File(
      p.join(fx.path, '.specify', 'memory', 'tdd-profile.md'),
    ).writeAsString('''
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
    await Directory(
      p.join(fx.path, 'specs', featureName, 'tdd'),
    ).create(recursive: true);
    await File(p.join(fx.path, 'specs', featureName, 'spec.md')).writeAsString(
      '''
# Spec: $featureName

## Functional Requirements

- **FR-001**: The system shall convert a sample pdf to markdown through the pdf-to-markdown ffi binding.
''',
    );
    // The hand-written native loop row (bug #835's declaration surface).
    await File(
      p.join(fx.path, 'specs', featureName, 'tdd', 'test-list.md'),
    ).writeAsString('''
# Test List: $featureName

## Native loop: ffi behaviors

| id | behavior | traces | state |
|----|----------|--------|-------|
| U1 | the pdf-to-markdown ffi binding converts a sample pdf to markdown | FR-001 | PENDING |
''');
    // The lane-semantics yaml (fresh-project shape).
    await File(
      p.join(fx.path, 'dart_test.yaml'),
    ).writeAsString(_fixtureDartTestYaml);
    // Real dependencies so the generated tests actually run.
    final pubGet = await _runDart(['pub', 'get'], workingDirectory: fx.path);
    expect(pubGet.exitCode, 0, reason: 'fixture pub get: ${pubGet.stdout}');
  });

  tearDownAll(() {
    if (fx.existsSync()) fx.deleteSync(recursive: true);
  });

  test(
    'gen emits the three surfaces for the native-boundary behavior',
    () async {
      final gen = await zfa(['gen', 'U1']);
      expect(
        gen.exitCode,
        0,
        reason:
            'gen stdout/stderr: ${gen.stdout} '
            '${gen.stderr}',
      );
      final testDir = p.join(fx.path, 'test', 'tdd', featureName);
      expect(File(p.join(testDir, 'u1_test.dart')).existsSync(), isTrue);
      expect(
        File(
          p.join(fx.path, 'lib', 'tdd', featureName, 'u1_subject.dart'),
        ).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(testDir, 'u1_golden_test.dart')).existsSync(),
        isTrue,
        reason: 'the marked golden fixture lane',
      );
      expect(
        File(
          p.join(testDir, 'fixtures', 'u1', 'golden-input.pdf'),
        ).existsSync(),
        isTrue,
      );
      expect(gen.stdout.toString(), contains('golden_test_path:'));
    },
  );

  test('verify-red certifies the honest binding-contract red', () async {
    final red = await zfa(['verify-red', 'U1']);
    expect(
      red.stdout.toString(),
      contains('classification=assertion'),
      reason: 'red output: ${red.stdout} ${red.stderr}',
    );
    expect(red.stdout.toString(), contains('certified=true'));
  });

  test('make refuses honestly: outcome=unexpressible (native work)', () async {
    final make = await zfa(['make', 'U1']);
    expect(make.exitCode, isNot(0));
    expect(make.stdout.toString(), contains('outcome=unexpressible'));
    expect(
      make.stdout.toString(),
      contains('ffi'),
      reason: 'the refusal names the native boundary and the wiring path',
    );
  });

  test('default tier: contract lane red, golden lane excluded', () async {
    final run = await _runDart([
      'test',
      'test/tdd/$featureName',
    ], workingDirectory: fx.path);
    expect(run.exitCode, 1, reason: 'the contract lane is honestly red');
    expect(
      run.stdout.toString(),
      contains('the pdf-to-markdown ffi binding'),
      reason: 'the contract test ran (named <id> — <description>)',
    );
    expect(
      run.stdout.toString(),
      isNot(contains('golden fixture')),
      reason:
          'the golden lane is excluded from the default tier '
          '(exclude_tags: slow)',
    );
  });

  test('wiring the binding + recording goldens flips both lanes green', () async {
    // Wire the in-memory stand-in for the production binding.
    final harnessPath = p.join(
      fx.path,
      'lib',
      'tdd',
      featureName,
      'u1_subject.dart',
    );
    final harness = File(harnessPath).readAsStringSync();
    final wired = harness
        .replaceFirst('NATIVE_LIBRARY_NOT_CONFIGURED', 'libpdf_to_md.so')
        .replaceFirst('REQUIRED_SYMBOL_NOT_CONFIGURED', 'pdf_convert')
        .replaceFirst(
          RegExp(
            r'bool symbolResolved\(String symbol\) =>\s*\n\s*throw UnimplementedError\([^;]*\);',
          ),
          "bool symbolResolved(String symbol) => symbol == 'pdf_convert';",
        )
        .replaceFirst(
          RegExp(
            r'String roundTrip\(String payload\) =>\s*\n\s*throw UnimplementedError\([^;]*\);',
          ),
          'String roundTrip(String payload) => payload;',
        )
        .replaceFirst(
          RegExp(
            r'String convertGolden\(String input\) =>\s*\n\s*throw UnimplementedError\([^;]*\);',
          ),
          r"String convertGolden(String input) => '# recorded golden markdown\n';",
        );
    expect(wired, isNot(contains('NATIVE_LIBRARY_NOT_CONFIGURED')));
    File(harnessPath).writeAsStringSync(wired);

    // Record the golden output the (wired) binding produces.
    File(
      p.join(
        fx.path,
        'test',
        'tdd',
        featureName,
        'fixtures',
        'u1',
        'golden-expected.md',
      ),
    ).writeAsStringSync('# recorded golden markdown\n');

    final contract = await _runDart([
      'test',
      'test/tdd/$featureName',
    ], workingDirectory: fx.path);
    expect(
      contract.exitCode,
      0,
      reason: 'contract lane: ${contract.stdout} ${contract.stderr}',
    );

    final lane = await _runDart([
      'test',
      '--preset=integration',
    ], workingDirectory: fx.path);
    expect(
      lane.exitCode,
      0,
      reason: 'golden lane: ${lane.stdout} ${lane.stderr}',
    );
    expect(
      lane.stdout.toString(),
      contains('golden fixture'),
      reason: 'the lane test ran under the integration preset',
    );
  });
}
