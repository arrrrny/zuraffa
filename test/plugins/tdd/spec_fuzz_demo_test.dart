/// The SEEDED WEAKNESS DEMO (spec 0967-spec-mutation-arena, acceptance
/// criterion 1) — REAL processes, no injection: a deliberately weak toy
/// feature first goes green, `zfa spec fuzz` flags it (mutants survive,
/// exit 1, ledger gaps appended), and the strengthened spec over the
/// SAME implementation kills every mutant (exit 0, certified).
///
/// Slow tier: every mutant spawn is a real `dart test` run inside a
/// throwaway project (`dart pub get` in setUp, the TddFixture
/// convention).
@Tags(['slow', 'integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

void main() {
  late Directory root;
  late CliRunner runner;
  const feature = 'demo-greeter';

  setUp(() async {
    runner = CliRunner(exitOnCompletion: false);
    root = await Directory.systemTemp.createTemp('spec_fuzz_demo_');
    await File(p.join(root.path, 'pubspec.yaml')).writeAsString('''
name: spec_fuzz_demo
environment:
  sdk: ^3.11.0
dev_dependencies:
  test: ^1.25.0
''');
    final pubGet = await Process.run('dart', [
      'pub',
      'get',
      '--no-example',
    ], workingDirectory: root.path);
    expect(pubGet.exitCode, 0, reason: 'pub get in the demo project');
  });

  tearDown(() async {
    exitCode = 0;
    if (root.existsSync()) await root.delete(recursive: true);
  });

  String featureDir([String f = feature]) => p.join(root.path, 'specs', f);

  Future<String> fuzz({List<String> extra = const []}) => runner.runCapturing([
    'spec',
    'fuzz',
    feature,
    '--project',
    root.path,
    ...extra,
  ]);

  Future<File> writeAt(String rel, String content) => File(
    p.join(root.path, rel),
  ).create(recursive: true).then((f) => f.writeAsString(content));

  Future<void> writeFixture({required bool strong, String f = feature}) async {
    final spec = strong ? _strongSpec : _weakSpec;
    await writeAt('specs/$f/spec.md', f == feature ? spec : _rename(spec, f));
    await writeAt(
      'specs/$f/tdd/artifacts.json',
      f == feature ? _artifacts : _rename(_artifacts, f),
    );
    final pinned = strong;
    await writeAt(
      'test/tdd/$f/a1_test.dart',
      _acceptanceTest(f, 'A1', 'AC-1', pinned: pinned ? 42 : null),
    );
    await writeAt(
      'test/tdd/$f/a2_test.dart',
      _acceptanceTest(f, 'A2', 'AC-2', pinned: pinned ? 0 : null),
    );
    await writeAt(
      'test/tdd/$f/u1_test.dart',
      _unitTest(f, 'U1', 'FR-001', pinned: pinned ? 42 : null),
    );
    await writeAt(
      'test/tdd/$f/u2_test.dart',
      _unitTest(f, 'U2', 'FR-002', pinned: pinned ? 0 : null),
    );
    await writeAt(
      'test/tdd/$f/u3_test.dart',
      _unitTest(f, 'U3', 'FR-003', pinned: pinned ? 100 : null),
    );
    await writeAt('lib/tdd/$f/a1_subject.dart', _subject(42));
    await writeAt('lib/tdd/$f/a2_subject.dart', _subject(0));
    await writeAt('lib/tdd/$f/u1_subject.dart', _subject(42));
    await writeAt('lib/tdd/$f/u2_subject.dart', _subject(0));
    await writeAt('lib/tdd/$f/u3_subject.dart', _subject(100));
  }

  test('the weak spec survives the green loop and spec fuzz flags it; the '
      'strengthened spec kills all mutants', () async {
    // ---- Phase 1: the weak feature goes green through the REAL loop
    // machinery (the suite preflight must pass before the fuzz runs).
    await writeFixture(strong: false);
    final suite = await Process.run('dart', [
      'test',
      'test/tdd/$feature/a1_test.dart',
      'test/tdd/$feature/a2_test.dart',
      'test/tdd/$feature/u1_test.dart',
      'test/tdd/$feature/u2_test.dart',
      'test/tdd/$feature/u3_test.dart',
    ], workingDirectory: root.path);
    expect(
      suite.exitCode,
      0,
      reason: 'the weak feature is green: ${suite.stdout}',
    );

    // ---- Phase 2: the fuzz flags it (real spawns, no injection).
    final weakOut = await fuzz();
    expect(weakOut, contains('spec-fuzz: feature=$feature'), reason: weakOut);
    expect(weakOut, contains('certified=false'));
    final weakSurvived = RegExp(
      r'survived=(\d+)',
    ).firstMatch(weakOut)?.group(1);
    expect(weakSurvived, isNotNull);
    expect(int.parse(weakSurvived!), greaterThan(0));
    expect(exitCode, 1, reason: 'survived > 0 must exit non-zero');
    expect(
      File(p.join(featureDir(), 'tdd', 'spec-fuzz.json')).existsSync(),
      isTrue,
    );

    // Ledger integration: survivors are contract gaps.
    final ledgerFile = File(
      p.join(root.path, '.zfa', 'corpus', 'gap-ledger.json'),
    );
    expect(ledgerFile.existsSync(), isTrue);
    final entries = (jsonDecode(await ledgerFile.readAsString()) as List)
        .cast<Map<String, dynamic>>();
    expect(entries, isNotEmpty);
    expect(
      entries.every((e) => e['severity'] == 'contract'),
      isTrue,
      reason: 'survived mutations are ledger gaps of the highest class',
    );

    // Restoration: the spec was mutated during the round and restored.
    expect(
      await File(p.join(featureDir(), 'spec.md')).readAsString(),
      _weakSpec,
    );

    // ---- Phase 3: the strengthened spec over the SAME implementation
    // kills every mutant.
    await writeFixture(strong: true);
    final strongOut = await fuzz();
    expect(
      strongOut,
      contains('spec-fuzz: feature=$feature'),
      reason: strongOut,
    );
    final strongSurvived = RegExp(
      r'survived=(\d+)',
    ).firstMatch(strongOut)?.group(1);
    expect(strongSurvived, '0', reason: strongOut);
    expect(strongOut, contains('certified=true'));
    expect(exitCode, 0, reason: 'all mutants killed must exit zero');

    // ---- Determinism: same seed, byte-identical report.
    final first = await File(
      p.join(featureDir(), 'tdd', 'spec-fuzz.json'),
    ).readAsString();
    await fuzz();
    final second = await File(
      p.join(featureDir(), 'tdd', 'spec-fuzz.json'),
    ).readAsString();
    expect(second, first);
  }, timeout: const Timeout(Duration(minutes: 8)));

  test(
    'corpus mode walks a cataloged corpus and gates on the weak feature',
    () async {
      // A two-feature corpus: one weak, one strong.
      await writeFixture(strong: false);
      await writeFixture(strong: true, f: 'strong-greeter');

      await Directory(
        p.join(root.path, 'corpus', 'catalogs'),
      ).create(recursive: true);
      await File(
        p.join(root.path, 'corpus', 'catalogs', 'demo.json'),
      ).writeAsString(
        jsonEncode({
          'target': 'demo',
          'generated_at': '2026-09-05T00:00:00Z',
          'source': 'manifest',
          'features': [
            {
              'name': feature,
              'classification': 'CORE',
              'ready': true,
              'reason': '',
              'spec_sha256': '0' * 64,
            },
            {
              'name': 'strong-greeter',
              'classification': 'CORE',
              'ready': true,
              'reason': '',
              'spec_sha256': '0' * 64,
            },
          ],
        }),
      );

      final out = await runner.runCapturing([
        'spec',
        'fuzz',
        '--corpus',
        'demo',
        '--project',
        root.path,
        '--no-ledger',
      ]);
      expect(out, contains('spec-fuzz: corpus=demo'), reason: out);
      expect(out, contains('features=2'));
      expect(exitCode, 1, reason: 'the weak feature survived the fuzz');
      expect(
        File(
          p.join(root.path, '.zfa', 'corpus', 'spec-fuzz', 'demo.json'),
        ).existsSync(),
        isTrue,
      );
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

String _rename(String text, String f) => text.replaceAll('demo-greeter', f);

const _weakSpec = '''
**Template Version**: `zuraffa-1.0`

# Feature Specification: Demo Greeter (weak)

**Feature Branch**: `demo-greeter`

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A vague greeter (Priority: P1)

**Acceptance Scenarios**:

1. **Given** any user, **When** the greeter greets, **Then** it shows the message 'Hello'.
   **Type**: acceptance
2. **Given** an empty name, **When** the greeter greets, **Then** it handles the empty case gracefully.
   **Type**: acceptance

### Functional Requirements

- **FR-001**: The greeter MUST return a greeting message.
- **FR-002**: The greeter MUST NOT fail when the name is empty.
- **FR-003**: The greeter MUST count at most 100 greetings.
''';

const _strongSpec = '''
**Template Version**: `zuraffa-1.0`

# Feature Specification: Demo Greeter (strong)

**Feature Branch**: `demo-greeter`

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A pinned greeter (Priority: P1)

**Acceptance Scenarios**:

1. **Given** any user, **When** the greeter greets, **Then** it returns 42 as the greeting code.
   **Type**: acceptance
2. **Given** an empty name, **When** the greeter greets, **Then** it returns 0 as the greeting code.
   **Type**: acceptance

### Functional Requirements

- **FR-001**: The greeter MUST return 42 as the greeting code when the name is not empty.
- **FR-002**: The greeter MUST return 0 when the name is empty; it MUST NOT return 42 in that case.
- **FR-003**: The greeter MUST accept greeting counts within 0..100 and MUST return 100 when full.
''';

const _artifacts = '''
{
  "feature": "demo-greeter",
  "records": [
    {
      "behavior_id": "A1",
      "feature": "demo-greeter",
      "source_criterion": "AC-1",
      "test_path": "test/tdd/demo-greeter/a1_test.dart",
      "subject_path": "lib/tdd/demo-greeter/a1_subject.dart",
      "runnable_test_name": "A1 — demo",
      "test_ownership": "created",
      "subject_ownership": "created",
      "created_at": "2026-09-05T00:00:00Z"
    },
    {
      "behavior_id": "A2",
      "feature": "demo-greeter",
      "source_criterion": "AC-2",
      "test_path": "test/tdd/demo-greeter/a2_test.dart",
      "subject_path": "lib/tdd/demo-greeter/a2_subject.dart",
      "runnable_test_name": "A2 — demo",
      "test_ownership": "created",
      "subject_ownership": "created",
      "created_at": "2026-09-05T00:00:00Z"
    },
    {
      "behavior_id": "U1",
      "feature": "demo-greeter",
      "source_criterion": "FR-001",
      "test_path": "test/tdd/demo-greeter/u1_test.dart",
      "subject_path": "lib/tdd/demo-greeter/u1_subject.dart",
      "runnable_test_name": "U1 — demo",
      "test_ownership": "created",
      "subject_ownership": "created",
      "created_at": "2026-09-05T00:00:00Z"
    },
    {
      "behavior_id": "U2",
      "feature": "demo-greeter",
      "source_criterion": "FR-002",
      "test_path": "test/tdd/demo-greeter/u2_test.dart",
      "subject_path": "lib/tdd/demo-greeter/u2_subject.dart",
      "runnable_test_name": "U2 — demo",
      "test_ownership": "created",
      "subject_ownership": "created",
      "created_at": "2026-09-05T00:00:00Z"
    },
    {
      "behavior_id": "U3",
      "feature": "demo-greeter",
      "source_criterion": "FR-003",
      "test_path": "test/tdd/demo-greeter/u3_test.dart",
      "subject_path": "lib/tdd/demo-greeter/u3_subject.dart",
      "runnable_test_name": "U3 — demo",
      "test_ownership": "created",
      "subject_ownership": "created",
      "created_at": "2026-09-05T00:00:00Z"
    }
  ]
}
''';

String _acceptanceTest(String f, String id, String criterion, {int? pinned}) =>
    '''
// ${pinned == null ? 'GENERIC (weak fixture)' : 'HAND-STRENGTHENED (strong fixture)'}.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/$f/${id.toLowerCase()}_subject.dart' as subject;

void main() {
  group('$id ($criterion)', () {
    test('$id — demo', () {
${pinned == null ? '''
      final result = (() {
        try {
          subject.subjectUnderTest();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
''' : '      expect(subject.subjectUnderTest(), equals($pinned));'}
    });
  });
}
''';

String _unitTest(String f, String id, String criterion, {int? pinned}) =>
    '''
// ${pinned == null ? 'GENERIC (weak fixture)' : 'PINNED (strong fixture)'}.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/$f/${id.toLowerCase()}_subject.dart' as subject;

void main() {
  group('$id ($criterion)', () {
    test('$id — demo', () {
      final result = (() {
        try {
          return subject.subjectUnderTest();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, ${pinned == null ? 'isNot(isA<UnimplementedError>())' : 'equals($pinned)'});
    });
  });
}
''';

String _subject(int value) =>
    '''
// IMPLEMENTED SUBJECT (spec 0967 demo).
library;

int subjectUnderTest() => $value;
''';
