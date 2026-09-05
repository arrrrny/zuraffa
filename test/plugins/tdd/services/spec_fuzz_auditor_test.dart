/// Unit tests for the spec-fuzz referee (spec 0967-spec-mutation-arena):
/// the P1/P2/P3 pin oracle, per-mutant capture/restore, gate decisions,
/// ledger integration, and deterministic reporting — with injectable
/// spawns (the MutationAuditor seam pattern).
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/spec_mutation.dart';
import 'package:zuraffa/src/plugins/tdd/services/gap_ledger_store.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_auditor.dart';
import 'package:zuraffa/src/plugins/tdd/services/spec_fuzz_auditor.dart';

/// Builds the toy greeter fixture: a temp project with a spec, an
/// artifacts registry, gen-shaped test files, and implemented subjects.
class _GreeterFixture {
  _GreeterFixture._(this.root, this.featureName);

  final Directory root;
  final String featureName;

  String get featureDir => p.join(root.path, 'specs', featureName);

  static const weakSpec = '''
**Template Version**: `zuraffa-1.0`

# Feature Specification: Fixture Greeter (weak)

**Feature Branch**: `fixture-greeter`

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
''';

  static const strongSpec = '''
**Template Version**: `zuraffa-1.0`

# Feature Specification: Fixture Greeter (strong)

**Feature Branch**: `fixture-greeter`

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
''';

  /// The gen-shaped generic unit test (no pins — the weak fixture).
  static String unitTest(String id, String criterion, String description) =>
      '''
// GENERATED TEST — `zfa tdd gen $id` (spec 044-test-tdd-generation).
//
// behavior_id: $id
// source_criterion: $criterion
// description: $description
library;

import 'package:test/test.dart';
import '../../../lib/tdd/fixture-greeter/${id.toLowerCase()}_subject.dart' as subject;

void main() {
  group('$id ($criterion)', () {
    test('$id — $description', () {
      final result = (() {
        try {
          return subject.subjectUnderTest();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
''';

  /// The gen-shaped invocation-only acceptance test (the weak fixture).
  static String acceptanceTest(
    String id,
    String criterion,
    String description,
  ) =>
      '''
// GENERATED TEST — `zfa tdd gen $id` (spec 044-test-tdd-generation).
//
// behavior_id: $id
// source_criterion: $criterion
// description: $description
library;

import 'package:test/test.dart';
import '../../../lib/tdd/fixture-greeter/${id.toLowerCase()}_subject.dart' as subject;

void main() {
  group('$id ($criterion)', () {
    test('$id — $description', () {
      final result = (() {
        try {
          subject.subjectUnderTest();
          return null;
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, isNot(isA<UnimplementedError>()));
    });
  });
}
''';

  /// A hand-strengthened acceptance test pinning a number (the strong
  /// fixture — what a strong spec demands of its implementer).
  static String pinnedAcceptanceTest(
    String id,
    String criterion,
    String description,
    int pin,
  ) =>
      '''
// GENERATED TEST — strengthened by the implementer to pin the declared
// code (spec 0967 demo).
//
// behavior_id: $id
// source_criterion: $criterion
// description: $description
library;

import 'package:test/test.dart';
import '../../../lib/tdd/fixture-greeter/${id.toLowerCase()}_subject.dart' as subject;

void main() {
  group('$id ($criterion)', () {
    test('$id — $description', () {
      expect(subject.subjectUnderTest(), equals($pin));
    });
  });
}
''';

  /// A gen-shaped unit test with the number heuristic pin.
  static String pinnedUnitTest(
    String id,
    String criterion,
    String description,
    int pin,
  ) =>
      '''
// GENERATED TEST — `zfa tdd gen $id` (spec 044-test-tdd-generation).
//
// behavior_id: $id
// source_criterion: $criterion
// description: $description
library;

import 'package:test/test.dart';
import '../../../lib/tdd/fixture-greeter/${id.toLowerCase()}_subject.dart' as subject;

void main() {
  group('$id ($criterion)', () {
    test('$id — $description', () {
      final result = (() {
        try {
          return subject.subjectUnderTest();
        } on UnimplementedError catch (error) {
          return error;
        }
      })();
      expect(result, equals($pin));
    });
  });
}
''';

  static String subject(int value) =>
      '''
// IMPLEMENTED SUBJECT (spec 0967 demo).
library;

int subjectUnderTest() => $value;
''';

  Future<void> write({required String spec, required bool strong}) async {
    await Directory(p.join(featureDir, 'tdd')).create(recursive: true);
    await File(p.join(featureDir, 'spec.md')).writeAsString(spec);

    final a1Test = strong
        ? pinnedAcceptanceTest('A1', 'AC-1', 'pinned', 42)
        : acceptanceTest('A1', 'AC-1', "it shows the message 'Hello'.");
    final a2Test = strong
        ? pinnedAcceptanceTest('A2', 'AC-2', 'pinned', 0)
        : acceptanceTest('A2', 'AC-2', 'it handles the empty case.');
    final u1Test = strong
        ? pinnedUnitTest(
            'U1',
            'FR-001',
            'The greeter MUST return 42 as the greeting code.',
            42,
          )
        : unitTest('U1', 'FR-001', 'The greeter MUST return a greeting.');
    final u2Test = strong
        ? pinnedUnitTest(
            'U2',
            'FR-002',
            'The greeter MUST return 0 when the name is empty.',
            0,
          )
        : unitTest('U2', 'FR-002', 'The greeter MUST NOT fail.');

    await File(
      p.join(root.path, 'test', 'tdd', 'fixture-greeter', 'a1_test.dart'),
    ).create(recursive: true).then((f) => f.writeAsString(a1Test));
    await File(
      p.join(root.path, 'test', 'tdd', 'fixture-greeter', 'a2_test.dart'),
    ).create(recursive: true).then((f) => f.writeAsString(a2Test));
    await File(
      p.join(root.path, 'test', 'tdd', 'fixture-greeter', 'u1_test.dart'),
    ).create(recursive: true).then((f) => f.writeAsString(u1Test));
    await File(
      p.join(root.path, 'test', 'tdd', 'fixture-greeter', 'u2_test.dart'),
    ).create(recursive: true).then((f) => f.writeAsString(u2Test));

    for (final entry in const {'a1': 42, 'a2': 0, 'u1': 42, 'u2': 0}.entries) {
      await File(
            p.join(
              root.path,
              'lib',
              'tdd',
              'fixture-greeter',
              '${entry.key}_subject.dart',
            ),
          )
          .create(recursive: true)
          .then((f) => f.writeAsString(subject(entry.value)));
    }

    final records = [
      _record('A1', 'AC-1', 'a1'),
      _record('A2', 'AC-2', 'a2'),
      _record('U1', 'FR-001', 'u1'),
      _record('U2', 'FR-002', 'u2'),
    ];
    await File(p.join(featureDir, 'tdd', 'artifacts.json')).writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'feature': featureName, 'records': records}),
    );
  }

  static Map<String, dynamic> _record(
    String behaviorId,
    String criterion,
    String slug,
  ) => {
    'behavior_id': behaviorId,
    'feature': 'fixture-greeter',
    'source_criterion': criterion,
    'test_path': 'test/tdd/fixture-greeter/${slug}_test.dart',
    'subject_path': 'lib/tdd/fixture-greeter/${slug}_subject.dart',
    'runnable_test_name': '$behaviorId — demo',
    'test_ownership': 'created',
    'subject_ownership': 'created',
    'created_at': '2026-09-05T00:00:00Z',
  };

  static Future<_GreeterFixture> create({bool strong = false}) async {
    final root = await Directory.systemTemp.createTemp('spec_fuzz_');
    final fx = _GreeterFixture._(root, 'fixture-greeter');
    await fx.write(spec: strong ? strongSpec : weakSpec, strong: strong);
    return fx;
  }
}

/// The honest fake spawn: reads the test file the writer regenerated,
/// extracts the `equals(<n>)` pin, and compares it against the paired
/// subject's return value — green when they match, red otherwise. A
/// test without an `equals(<n>)` pin is green (the writer's generic
/// shape passes against implemented subjects).
Future<ProcessResult> _fakeSpawn(
  String executable,
  List<String> args,
  String workingDirectory,
  Duration timeout,
) async {
  final testPath = args.where((a) => a.endsWith('_test.dart')).first;
  final abs = p.isAbsolute(testPath)
      ? testPath
      : p.join(workingDirectory, testPath);
  final content = File(abs).readAsStringSync();
  final equals = RegExp(r'equals\((\d+)\)').firstMatch(content);
  final subjectMatch = RegExp(
    r"import\s+'([^']*_subject\.dart)'\s+as\s+subject",
  ).firstMatch(content);
  if (equals == null || subjectMatch == null) {
    return ProcessResult(42, 0, 'All tests passed!', '');
  }
  final subjectPath = p.normalize(
    p.join(p.dirname(abs), subjectMatch.group(1)!),
  );
  final subjectContent = File(subjectPath).readAsStringSync();
  final value = RegExp(r'=>\s*(\d+);').firstMatch(subjectContent);
  final expected = int.parse(equals.group(1)!);
  final actual = value == null ? null : int.parse(value.group(1)!);
  if (actual == expected) {
    return ProcessResult(42, 0, 'All tests passed!', '');
  }
  return ProcessResult(
    42,
    1,
    '00:00 +0: $testPath [E]\n'
        'Expected: <$expected>\n'
        '  Actual: <$actual>',
    '',
  );
}

void main() {
  tearDown(() => exitCode = 0);

  group('weak fixture: every mutant survives and is flagged', () {
    test('gate fail_survived, ledger gaps appended, exit semantics', () async {
      final fx = await _GreeterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));

      final specBefore = crypto.sha256
          .convert(File(p.join(fx.featureDir, 'spec.md')).readAsBytesSync())
          .toString();

      final auditor = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: _fakeSpawn,
        ledgerStore: GapLedgerStore(
          fx.root.path,
          clock: () => DateTime.utc(2026, 1, 1),
        ),
      );
      final report = await auditor.run();

      expect(report.gate, SpecFuzzGateDecision.failSurvived);
      expect(report.survivedCount, greaterThan(0));
      expect(report.killedCount, 0);
      expect(report.certified, isFalse);
      expect(report.restorationVerified, isTrue);

      // Every survived row names its pins checked-and-silent.
      for (final outcome in report.outcomes) {
        if (outcome.verdict == SpecFuzzVerdict.survived) {
          expect(outcome.evidence, contains('no pin fired'));
        }
      }

      // Ledger: one deduplicated contract gap per survivor.
      final ledger = GapLedgerStore(
        fx.root.path,
        clock: () => DateTime.utc(2026, 1, 1),
      );
      final entries = await ledger.load();
      expect(entries.length, report.survivedCount);
      expect(entries.every((e) => e.severity == 'contract'), isTrue);
      expect(entries.every((e) => e.expectedResult == 'pass'), isTrue);

      // spec.md restored byte-exactly.
      final specAfter = crypto.sha256
          .convert(File(p.join(fx.featureDir, 'spec.md')).readAsBytesSync())
          .toString();
      expect(specAfter, specBefore);

      // Machine summary line (the CI contract).
      final line = report.summaryLine();
      expect(line, startsWith('spec-fuzz: feature=fixture-greeter'));
      expect(line, contains('survived=${report.survivedCount}'));
      expect(line, contains('certified=false'));
      expect(line, contains('fuzz_was_run=true'));

      // Report files written.
      expect(
        File(p.join(fx.featureDir, 'tdd', 'spec-fuzz.json')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(fx.featureDir, 'tdd', 'spec-fuzz.md')).existsSync(),
        isTrue,
      );

      // Second run: no duplicate ledger rows (dedupe on unresolved
      // feature + mutation_id).
      final auditor2 = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: _fakeSpawn,
        ledgerStore: ledger,
      );
      await auditor2.run();
      expect((await ledger.load()).length, report.survivedCount);
    });

    test('re-running with --no-ledger never touches the ledger', () async {
      final fx = await _GreeterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      final auditor = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        ledgerEnabled: false,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: _fakeSpawn,
      );
      final report = await auditor.run();
      expect(report.ledgerEntryIds, isEmpty);
      expect(
        File(
          p.join(fx.root.path, '.zfa', 'corpus', 'gap-ledger.json'),
        ).existsSync(),
        isFalse,
      );
    });
  });

  group('strong fixture: every mutant is killed', () {
    test('gate pass, certified=true, pins recorded', () async {
      final fx = await _GreeterFixture.create(strong: true);
      addTearDown(() => fx.root.delete(recursive: true));

      final auditor = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: _fakeSpawn,
      );
      final report = await auditor.run();

      expect(report.gate, SpecFuzzGateDecision.pass);
      expect(report.survivedCount, 0);
      expect(report.notAssessedCount, 0);
      expect(report.killedCount, greaterThan(0));
      expect(report.certified, isTrue);
      expect(report.summaryLine(), contains('certified=true'));

      // The kill evidence names a fired pin for every killed mutant.
      for (final outcome in report.outcomes) {
        expect(outcome.verdict, SpecFuzzVerdict.killed);
        expect(outcome.pins, isNotEmpty);
        expect(
          outcome.evidence,
          anyOf(contains('P1'), contains('P2'), contains('P3')),
        );
      }

      // P2 must have actually fired for the FR-001 number swap: the
      // regenerated test asserted the swapped number and went red.
      final swap42 = report.outcomes.where(
        (o) => o.candidate.element == 'FR-001:literal:42',
      );
      expect(swap42, isNotEmpty);
      expect(swap42.single.pins, contains('P2:loop-red'));

      // Determinism: a fresh run over the same fixture is byte-identical.
      final json1 = await File(
        p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
      ).readAsString();
      final auditor2 = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: _fakeSpawn,
      );
      await auditor2.run();
      final json2 = await File(
        p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
      ).readAsString();
      expect(json2, json1);
    });
  });

  group('honest refusals', () {
    test('missing artifacts registry: not_assessed', () async {
      final fx = await _GreeterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      File(p.join(fx.featureDir, 'tdd', 'artifacts.json')).deleteSync();
      final auditor = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
      );
      final report = await auditor.run();
      expect(report.gate, SpecFuzzGateDecision.notAssessed);
      expect(report.notAssessedReason, contains('no behavior artifacts'));
      expect(report.certified, isFalse);
    });

    test('red preflight: preflight_red gate (refuse to fuzz red)', () async {
      final fx = await _GreeterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      final auditor = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        runPreflight: (_) async =>
            PreflightResult(exitCode: 1, output: 'some test failed'),
      );
      final report = await auditor.run();
      expect(report.gate, SpecFuzzGateDecision.preflightRed);
      expect(report.mutationWasRun, isFalse);
    });

    test(
      'spawn load failure: not_assessed for that mutant, never a kill',
      () async {
        final fx = await _GreeterFixture.create();
        addTearDown(() => fx.root.delete(recursive: true));
        final auditor = SpecFuzzAuditor(
          featureDir: fx.featureDir,
          workingDirectory: fx.root.path,
          runPreflight: (_) async =>
              PreflightResult.green(exitCode: 0, output: 'ok'),
          spawnTest: (_, args, _, _) async {
            final path = args.where((a) => a.endsWith('_test.dart')).first;
            return ProcessResult(
              42,
              253,
              'Failed to load "$path": compile error',
              '',
            );
          },
        );
        final report = await auditor.run();
        expect(report.gate, SpecFuzzGateDecision.notAssessed);
        expect(report.notAssessedCount, greaterThan(0));
        // Every mutant that SPAWNED graded not_assessed (infrastructure);
        // the drop mutant needs no spawn, so it alone may survive — never
        // an invented kill, never a pass.
        expect(
          report.notAssessedCount + report.survivedCount,
          report.outcomes.length,
        );
        expect(report.killedCount, 0);
      },
    );

    test(
      'no mutation candidates: not_assessed, never a vacuous pass',
      () async {
        final fx = await _GreeterFixture.create();
        addTearDown(() => fx.root.delete(recursive: true));
        final auditor = SpecFuzzAuditor(
          featureDir: fx.featureDir,
          workingDirectory: fx.root.path,
          operators: const {SpecMutationOperator.widen},
          runPreflight: (_) async =>
              PreflightResult.green(exitCode: 0, output: 'ok'),
          spawnTest: _fakeSpawn,
        );
        final report = await auditor.run();
        expect(report.gate, SpecFuzzGateDecision.notAssessed);
        expect(report.notAssessedReason, contains('no mutation candidates'));
        expect(report.certified, isFalse);
      },
    );
  });

  group('budget and seed', () {
    test('budget caps the mutants and is recorded', () async {
      final fx = await _GreeterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      final auditor = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        budget: 2,
        seed: 0,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: _fakeSpawn,
      );
      final report = await auditor.run();
      expect(report.outcomes, hasLength(2));
      expect(report.budget, 2);
      expect(report.candidateCount, greaterThan(2));
      expect(report.summaryLine(), contains('budget=2'));
    });

    test('the same seed selects the same mutants', () async {
      final fx = await _GreeterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      Future<SpecFuzzReport> run(int seed) async {
        final auditor = SpecFuzzAuditor(
          featureDir: fx.featureDir,
          workingDirectory: fx.root.path,
          budget: 2,
          seed: seed,
          runPreflight: (_) async =>
              PreflightResult.green(exitCode: 0, output: 'ok'),
          spawnTest: _fakeSpawn,
        );
        return auditor.run();
      }

      final a = await run(11);
      final b = await run(11);
      expect(
        a.outcomes.map((o) => o.candidate.mutationId).toList(),
        b.outcomes.map((o) => o.candidate.mutationId).toList(),
      );
    });
  });

  group('report shape', () {
    test('machine rows carry the issue contract fields', () async {
      final fx = await _GreeterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      final auditor = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: _fakeSpawn,
      );
      await auditor.run();
      final decoded =
          jsonDecode(
                File(
                  p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(decoded['schema'], 'spec-fuzz.v1');
      final mutations = decoded['mutations'] as List;
      expect(mutations, isNotEmpty);
      for (final row in mutations.cast<Map<String, dynamic>>()) {
        expect(row.containsKey('mutation_id'), isTrue);
        expect(row.containsKey('spec_line'), isTrue);
        expect(row.containsKey('operator'), isTrue);
        expect(row.containsKey('verdict'), isTrue);
        expect(row.containsKey('evidence'), isTrue);
      }
      expect(decoded['seed'], 0);
      expect(decoded.containsKey('certified'), isTrue);
      final restoration = decoded['restoration'] as Map<String, dynamic>;
      expect(restoration.containsKey('verified'), isTrue);
    });

    test('spec hash binds the report to the audited spec bytes', () async {
      final fx = await _GreeterFixture.create();
      addTearDown(() => fx.root.delete(recursive: true));
      final auditor = SpecFuzzAuditor(
        featureDir: fx.featureDir,
        workingDirectory: fx.root.path,
        runPreflight: (_) async =>
            PreflightResult.green(exitCode: 0, output: 'ok'),
        spawnTest: _fakeSpawn,
      );
      final report = await auditor.run();
      final specHash = crypto.sha256
          .convert(File(p.join(fx.featureDir, 'spec.md')).readAsBytesSync())
          .toString();
      expect(report.specHash, specHash);
    });
  });
}
