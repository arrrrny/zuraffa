/// CLI run-semantics pins for `zfa spec fuzz` (spec
/// 1147-spec-fuzz-mutation-arena, issue #1147 — VISION-3, extends #967).
///
/// The six issue constraints, pinned at the COMMAND boundary on the fast
/// tier: the real [SpecFuzzCommand] with the auditor's injectable-spawn
/// seam (the MutationAuditor pattern — no subprocess), driving the honest
/// fake spawn from the `spec_fuzz_auditor_test.dart` convention:
///
///   1. the five operators apply deterministically and replayably,
///   2. behaviors are re-run against the mutated spec (the P2 pin via
///      the fake spawn),
///   3. killed vs survived is classified with evidence,
///   4. the machine-readable report carries the documented row shape,
///   5. exit 0 when every mutant is killed, non-zero when survived > 0,
///   6. `--budget N` caps the round.
///
/// The slow-tier seeded-weakness demo (`spec_fuzz_demo_test.dart`)
/// remains the real-process corroboration of the same contract.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/commands/spec_command.dart';
import 'package:zuraffa/src/plugins/tdd/services/mutation_auditor.dart';

import '../helpers/exit_span_mutex.dart';

Future<String> captureOutput(Future<void> Function() body) async {
  final output = <String>[];
  await runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        output.add(line);
      },
    ),
  );
  return output.join('\n');
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

Future<PreflightResult> _greenPreflight(List<String> testPaths) async =>
    PreflightResult(
      exitCode: 0,
      output: 'All tests passed!',
      ranTestPaths: testPaths,
    );

Future<PreflightResult> _redPreflight(List<String> testPaths) async =>
    PreflightResult(
      exitCode: 1,
      output: '00:00 +0 -1: Some tests failed.',
      ranTestPaths: testPaths,
    );

/// The arena fixture: a temp project whose spec carries ALL FIVE
/// mutation element classes (a quoted literal Then -> weaken, an
/// edge-case scenario -> drop, declared literals/numbers ->
/// swap-literal, a 0..100 range -> widen, a MUST NOT clause ->
/// drop-must-not), a registered artifacts registry, gen-shaped tests,
/// and implemented subjects.
class _ArenaFixture {
  _ArenaFixture._(this.root, this.featureName);

  final Directory root;
  final String featureName;

  String get featureDir => p.join(root.path, 'specs', featureName);

  static const weakSpec = '''
**Template Version**: `zuraffa-1.0`

# Feature Specification: Arena Greeter (weak)

**Feature Branch**: `arena-greeter`

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A vague greeter (Priority: P1)

**Acceptance Scenarios**:

1. **Given** any user, **When** the greeter greets, **Then** it shows the message 'Hello'.
   **Type**: acceptance
2. **Given** an empty name, **When** the greeter greets, **Then** it handles the empty case gracefully.
   **Type**: acceptance

### Functional Requirements

- **FR-001**: The greeter MUST return a greeting message.
  traces: Greeter
- **FR-002**: The greeter MUST NOT fail when the name is empty.
  traces: Greeter
- **FR-003**: The greeter MUST accept greeting counts within 0..100.
  traces: Greeter
''';

  static const strongSpec = '''
**Template Version**: `zuraffa-1.0`

# Feature Specification: Arena Greeter (strong)

**Feature Branch**: `arena-greeter`

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A pinned greeter (Priority: P1)

**Acceptance Scenarios**:

1. **Given** any user, **When** the greeter greets, **Then** it returns 42 as the greeting code.
   **Type**: acceptance
2. **Given** an empty name, **When** the greeter greets, **Then** it returns 0 as the greeting code.
   **Type**: acceptance

### Functional Requirements

- **FR-001**: The greeter MUST return 42 as the greeting code when the name is not empty.
  traces: Greeter
- **FR-002**: The greeter MUST return 0 when the name is empty; it MUST NOT return 42 in that case.
  traces: Greeter
- **FR-003**: The greeter MUST accept greeting counts within 0..100 and MUST return 100 when full.
  traces: Greeter
''';

  static String unitTest(String id, String criterion, String description) =>
      '''
// GENERATED TEST — `zfa tdd gen $id` (spec 044-test-tdd-generation).
//
// behavior_id: $id
// source_criterion: $criterion
// description: $description
library;

import 'package:test/test.dart';
import '../../../lib/tdd/arena-greeter/${id.toLowerCase()}_subject.dart' as subject;

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
import '../../../lib/tdd/arena-greeter/${id.toLowerCase()}_subject.dart' as subject;

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

  static String pinnedUnitTest(
    String id,
    String criterion,
    String description,
    int pin,
  ) =>
      '''
// GENERATED TEST — strengthened by the implementer to pin the declared
// code (spec 1147 fixture).
//
// behavior_id: $id
// source_criterion: $criterion
// description: $description
library;

import 'package:test/test.dart';
import '../../../lib/tdd/arena-greeter/${id.toLowerCase()}_subject.dart' as subject;

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

  static String pinnedAcceptanceTest(
    String id,
    String criterion,
    String description,
    int pin,
  ) =>
      '''
// GENERATED TEST — strengthened by the implementer to pin the declared
// code (spec 1147 fixture).
//
// behavior_id: $id
// source_criterion: $criterion
// description: $description
library;

import 'package:test/test.dart';
import '../../../lib/tdd/arena-greeter/${id.toLowerCase()}_subject.dart' as subject;

void main() {
  group('$id ($criterion)', () {
    test('$id — $description', () {
      expect(subject.subjectUnderTest(), equals($pin));
    });
  });
}
''';

  static String subject(int value) =>
      '''
// IMPLEMENTED SUBJECT (spec 1147 fixture).
library;

int subjectUnderTest() => $value;
''';

  Future<void> write({required String spec, required bool strong}) async {
    await Directory(p.join(featureDir, 'tdd')).create(recursive: true);
    await File(p.join(featureDir, 'spec.md')).writeAsString(spec);

    final pins = strong
        ? const {'a1': 42, 'a2': 0, 'u1': 42, 'u2': 0, 'u3': 100}
        : const {'a1': null, 'a2': null, 'u1': null, 'u2': null, 'u3': null};

    String testFor(String id, String criterion, String key) {
      final pin = pins[key];
      final isAcceptance = id.startsWith('A');
      if (pin == null) {
        return isAcceptance
            ? acceptanceTest(id, criterion, 'generic')
            : unitTest(id, criterion, 'generic');
      }
      return isAcceptance
          ? pinnedAcceptanceTest(id, criterion, 'pinned', pin)
          : pinnedUnitTest(id, criterion, 'pinned', pin);
    }

    final tests = {
      'a1': testFor('A1', 'AC-1', 'a1'),
      'a2': testFor('A2', 'AC-2', 'a2'),
      'u1': testFor('U1', 'FR-001', 'u1'),
      'u2': testFor('U2', 'FR-002', 'u2'),
      'u3': testFor('U3', 'FR-003', 'u3'),
    };
    for (final entry in tests.entries) {
      await File(
        p.join(
          root.path,
          'test',
          'tdd',
          'arena-greeter',
          '${entry.key}_test.dart',
        ),
      ).create(recursive: true).then((f) => f.writeAsString(entry.value));
    }
    for (final entry in {
      'a1': 42,
      'a2': 0,
      'u1': 42,
      'u2': 0,
      'u3': 100,
    }.entries) {
      await File(
            p.join(
              root.path,
              'lib',
              'tdd',
              'arena-greeter',
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
      _record('U3', 'FR-003', 'u3'),
    ];
    await File(p.join(featureDir, 'tdd', 'artifacts.json')).writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'feature': featureName, 'records': records}),
    );
  }

  Map<String, dynamic> _record(
    String behaviorId,
    String criterion,
    String slug,
  ) => {
    'behavior_id': behaviorId,
    'feature': featureName,
    'source_criterion': criterion,
    'test_path': 'test/tdd/arena-greeter/${slug}_test.dart',
    'subject_path': 'lib/tdd/arena-greeter/${slug}_subject.dart',
    'runnable_test_name': '$behaviorId — arena',
    'test_ownership': 'created',
    'subject_ownership': 'created',
    'created_at': '2026-09-18T00:00:00Z',
  };

  static Future<_ArenaFixture> create({required bool strong}) async {
    final root = await Directory.systemTemp.createTemp('spec_fuzz_1147_');
    final fx = _ArenaFixture._(root, 'arena-greeter');
    await fx.write(spec: strong ? strongSpec : weakSpec, strong: strong);
    return fx;
  }
}

void main() {
  tearDown(() => exitCode = 0);

  /// Dispatches the REAL spec-fuzz command (with the injected
  /// preflight/spawn seams) through a local CommandRunner — the
  /// skin_command_test pattern, holding the cross-isolate exit-span
  /// mutex around the dispatch + exitCode read.
  /// Holds the UsageException message so the refusal-class assertions
  /// can still inspect the command's verdict text.
  Future<(String, int)> runFuzz(
    List<String> args, {
    Future<PreflightResult> Function(List<String> testPaths)? preflight,
  }) async {
    await ExitSpanMutex.acquire();
    try {
      exitCode = 0;
      final runner = CommandRunner<void>('zfa', 'test')
        ..addCommand(
          SpecCommand(
            runPreflight: preflight ?? _greenPreflight,
            spawnTest: _fakeSpawn,
          ),
        );
      final output = await captureOutput(
        () => runner.run(['spec', 'fuzz', ...args]),
      );
      return (output, exitCode);
    } on UsageException catch (error) {
      // The runner rethrows usage-class refusals; CliRunner translates
      // them to the canonical usage exit (2) and prints the message.
      return (error.message, _usageExit);
    } finally {
      ExitSpanMutex.release();
    }
  }

  group('run semantics (issue #1147: exit codes)', () {
    test('weak spec: mutants survive, exit 1, certified=false', () async {
      final fx = await _ArenaFixture.create(strong: false);
      addTearDown(() => fx.root.delete(recursive: true));

      final (out, code) = await runFuzz([
        fx.featureName,
        '--project',
        fx.root.path,
        '--no-ledger',
      ]);
      expect(code, 1, reason: 'survived > 0 must exit non-zero — got:\n$out');
      expect(out, contains('spec-fuzz: feature=${fx.featureName}'));
      expect(out, contains('certified=false'));
      final survived = RegExp(r'survived=(\d+)').firstMatch(out)?.group(1);
      expect(survived, isNotNull);
      expect(int.parse(survived!), greaterThan(0));
      // The report exists and every row is a survived weakness with
      // evidence (constraint 3).
      final report =
          jsonDecode(
                await File(
                  p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(report['gate'], 'failSurvived');
      expect(report['certified'], false);
    });

    test('strong spec: every mutant killed, exit 0, certified=true', () async {
      final fx = await _ArenaFixture.create(strong: true);
      addTearDown(() => fx.root.delete(recursive: true));

      final (out, code) = await runFuzz([
        fx.featureName,
        '--project',
        fx.root.path,
        '--no-ledger',
      ]);
      expect(code, 0, reason: 'all mutants killed must exit zero — got:\n$out');
      expect(out, contains('certified=true'));
      final survived = RegExp(r'survived=(\d+)').firstMatch(out)?.group(1);
      expect(survived, '0', reason: out);
      final killed = RegExp(r'killed=(\d+)').firstMatch(out)?.group(1);
      expect(int.parse(killed!), greaterThan(0));
      final report =
          jsonDecode(
                await File(
                  p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(report['gate'], 'pass');
      expect(report['certified'], true);
    });
  });

  group('report shape (issue #1147: machine-readable weakness report)', () {
    test('rows carry the documented fields {mutation_id, spec_line, '
        'operator, verdict, evidence}', () async {
      final fx = await _ArenaFixture.create(strong: false);
      addTearDown(() => fx.root.delete(recursive: true));

      await runFuzz([fx.featureName, '--project', fx.root.path, '--no-ledger']);
      final report =
          jsonDecode(
                await File(
                  p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(report['schema'], 'spec-fuzz.v1');
      final mutations = (report['mutations'] as List)
          .cast<Map<String, dynamic>>();
      expect(mutations, isNotEmpty);
      for (final row in mutations) {
        expect(row['mutation_id'], matches(RegExp(r'^SM-\d{3}$')));
        expect(row['spec_line'], isA<int>(), reason: '$row');
        expect((row['spec_line'] as int), greaterThan(0));
        expect(
          row['operator'],
          anyOf('weaken', 'drop', 'swap-literal', 'widen', 'drop-must-not'),
          reason: '$row',
        );
        expect(row['verdict'], anyOf('killed', 'survived', 'not_assessed'));
        expect((row['evidence'] as String), isNotEmpty, reason: '$row');
      }
    });

    test('the five declared operators all appear against the '
        'all-element fixture', () async {
      final fx = await _ArenaFixture.create(strong: false);
      addTearDown(() => fx.root.delete(recursive: true));

      await runFuzz([fx.featureName, '--project', fx.root.path, '--no-ledger']);
      final report =
          jsonDecode(
                await File(
                  p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      final operators =
          ((report['mutations'] as List).cast<Map<String, dynamic>>())
              .map((row) => row['operator'] as String)
              .toSet();
      expect(
        operators,
        containsAll([
          'weaken',
          'drop',
          'swap-literal',
          'widen',
          'drop-must-not',
        ]),
        reason: 'the fixture spec carries all five element classes',
      );
    });
  });

  group('operator filter (issue #1147: --operators)', () {
    test(
      '--operators weaken,drop judges only the selected operators',
      () async {
        final fx = await _ArenaFixture.create(strong: false);
        addTearDown(() => fx.root.delete(recursive: true));

        final (out, code) = await runFuzz([
          fx.featureName,
          '--project',
          fx.root.path,
          '--operators',
          'weaken,drop',
          '--no-ledger',
        ]);
        expect(code, 1, reason: out);
        final report =
            jsonDecode(
                  await File(
                    p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                  ).readAsString(),
                )
                as Map<String, dynamic>;
        final mutations = (report['mutations'] as List)
            .cast<Map<String, dynamic>>()
            .map((row) => row['operator'] as String)
            .toSet();
        expect(mutations.difference({'weaken', 'drop'}), isEmpty, reason: out);
        expect(report['operators'], ['drop', 'weaken']);

        // The unfiltered round on the same fixture is strictly larger —
        // the filter actually narrowed the candidate set (ids stay stable;
        // the count reflects the full candidate set either way).
        await runFuzz([
          fx.featureName,
          '--project',
          fx.root.path,
          '--no-ledger',
        ]);
        final unfiltered =
            jsonDecode(
                  await File(
                    p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                  ).readAsString(),
                )
                as Map<String, dynamic>;
        expect(
          (report['candidate_count'] as int),
          lessThan(unfiltered['candidate_count'] as int),
          reason: 'the filter must narrow the candidate set',
        );
      },
    );
  });

  group('budget (issue #1147: --budget N)', () {
    test('--budget 2 caps the judged mutants and is recorded', () async {
      final fx = await _ArenaFixture.create(strong: false);
      addTearDown(() => fx.root.delete(recursive: true));

      final (out, code) = await runFuzz([
        fx.featureName,
        '--project',
        fx.root.path,
        '--budget',
        '2',
        '--no-ledger',
      ]);
      expect(code, 1, reason: out);
      final report =
          jsonDecode(
                await File(
                  p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
                ).readAsString(),
              )
              as Map<String, dynamic>;
      expect(report['budget'], 2);
      expect(report['candidate_count'], greaterThan(2));
      expect(
        (report['mutations'] as List).length,
        2,
        reason: 'exactly budget mutants are judged — got:\n$out',
      );
    });
  });

  group('replay (issue #1147: deterministic, replayable)', () {
    test('same seed + budget -> byte-identical report', () async {
      final fx = await _ArenaFixture.create(strong: false);
      addTearDown(() => fx.root.delete(recursive: true));

      final args = [
        fx.featureName,
        '--project',
        fx.root.path,
        '--seed',
        '7',
        '--budget',
        '3',
        '--no-ledger',
      ];
      await runFuzz(args);
      final first = await File(
        p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
      ).readAsString();
      await runFuzz(args);
      final second = await File(
        p.join(fx.featureDir, 'tdd', 'spec-fuzz.json'),
      ).readAsString();
      expect(second, first, reason: 'the round must replay byte-identically');
    });
  });

  group('honest refusals (issue #1147: never grade a red loop)', () {
    test('a red preflight is refused, never graded (usage exit)', () async {
      final fx = await _ArenaFixture.create(strong: false);
      addTearDown(() => fx.root.delete(recursive: true));

      final (out, code) = await runFuzz([
        fx.featureName,
        '--project',
        fx.root.path,
        '--no-ledger',
      ], preflight: _redPreflight);
      expect(code, 2, reason: 'preflight_red is a refusal class — got:\n$out');
      // The refusal names the gate (enum name) and the honest reason.
      expect(out, contains('preflightRed'));
      expect(out, contains('refuses'));
      expect(out, contains('red loop'));
      // No report was written for an unrun round.
      expect(
        File(p.join(fx.featureDir, 'tdd', 'spec-fuzz.json')).existsSync(),
        isFalse,
      );
    });
  });
}

/// The canonical usage exit the CliRunner applies to usage-class
/// refusals (SPEC 917: legacy 64 maps onto 2).
const int _usageExit = 2;
