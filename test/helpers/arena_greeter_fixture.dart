/// The shared greeter fixture behind both spec-fuzz suites: the auditor
/// unit tests (spec 0967) and the command run-semantics pins (spec 1147)
/// drive the same toy greeter project, and this helper is the single copy
/// of that generation — the weak/strong spec strings, the gen-shaped test
/// generators, the implemented subjects, and the artifacts registry — so
/// the two suites cannot drift.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One fixture behavior row: the artifacts-registry record fields, the
/// weak/strong test descriptions, and the `equals(<n>)` pin the strong
/// fixture strengthens the behavior's test with (the subject's return
/// value in both modes).
class GreeterBehavior {
  const GreeterBehavior(
    this.behaviorId,
    this.sourceCriterion,
    this.slug, {
    required this.pin,
    required this.weakDescription,
    required this.strongDescription,
  });

  final String behaviorId;
  final String sourceCriterion;
  final String slug;

  /// The declared greeting code: the subject's return value, and the
  /// `equals(<n>)` pin of the hand-strengthened strong-fixture test.
  final int pin;

  /// The test description on the weak fixture (the generic gen shape).
  final String weakDescription;

  /// The test description on the strong fixture.
  final String strongDescription;
}

/// The toy greeter project behind both spec-fuzz suites: a temp project
/// whose spec carries the mutation element classes, a registered
/// artifacts registry, gen-shaped tests, and implemented subjects.
class ArenaGreeterFixture {
  ArenaGreeterFixture._({required this.root, required this.featureName});

  final Directory root;
  final String featureName;

  String get featureDir => p.join(root.path, 'specs', featureName);

  /// The 1147 arena variant: a temp project whose spec carries ALL FIVE
  /// mutation element classes (a quoted literal Then -> weaken, an
  /// edge-case scenario -> drop, declared literals/numbers ->
  /// swap-literal, a 0..100 range -> widen, a MUST NOT clause ->
  /// drop-must-not) — five behaviors, pinned on the strong fixture.
  static Future<ArenaGreeterFixture> arena({required bool strong}) => _create(
    featureName: 'arena-greeter',
    tempPrefix: 'spec_fuzz_1147_',
    tag: 'spec 1147 fixture',
    runnableLabel: 'arena',
    createdAt: '2026-09-18T00:00:00Z',
    weakSpec: _arenaWeakSpec,
    strongSpec: _arenaStrongSpec,
    strong: strong,
    behaviors: const [
      GreeterBehavior(
        'A1',
        'AC-1',
        'a1',
        pin: 42,
        weakDescription: 'generic',
        strongDescription: 'pinned',
      ),
      GreeterBehavior(
        'A2',
        'AC-2',
        'a2',
        pin: 0,
        weakDescription: 'generic',
        strongDescription: 'pinned',
      ),
      GreeterBehavior(
        'U1',
        'FR-001',
        'u1',
        pin: 42,
        weakDescription: 'generic',
        strongDescription: 'pinned',
      ),
      GreeterBehavior(
        'U2',
        'FR-002',
        'u2',
        pin: 0,
        weakDescription: 'generic',
        strongDescription: 'pinned',
      ),
      GreeterBehavior(
        'U3',
        'FR-003',
        'u3',
        pin: 100,
        weakDescription: 'generic',
        strongDescription: 'pinned',
      ),
    ],
  );

  /// The 0967 auditor variant: the fixture greeter — four behaviors,
  /// pinned on the strong fixture, weak prose on the weak one.
  static Future<ArenaGreeterFixture> greeter({bool strong = false}) => _create(
    featureName: 'fixture-greeter',
    tempPrefix: 'spec_fuzz_',
    tag: 'spec 0967 demo',
    runnableLabel: 'demo',
    createdAt: '2026-09-05T00:00:00Z',
    weakSpec: _greeterWeakSpec,
    strongSpec: _greeterStrongSpec,
    strong: strong,
    behaviors: const [
      GreeterBehavior(
        'A1',
        'AC-1',
        'a1',
        pin: 42,
        weakDescription: "it shows the message 'Hello'.",
        strongDescription: 'pinned',
      ),
      GreeterBehavior(
        'A2',
        'AC-2',
        'a2',
        pin: 0,
        weakDescription: 'it handles the empty case.',
        strongDescription: 'pinned',
      ),
      GreeterBehavior(
        'U1',
        'FR-001',
        'u1',
        pin: 42,
        weakDescription: 'The greeter MUST return a greeting.',
        strongDescription: 'The greeter MUST return 42 as the greeting code.',
      ),
      GreeterBehavior(
        'U2',
        'FR-002',
        'u2',
        pin: 0,
        weakDescription: 'The greeter MUST NOT fail.',
        strongDescription: 'The greeter MUST return 0 when the name is empty.',
      ),
    ],
  );

  static Future<ArenaGreeterFixture> _create({
    required String featureName,
    required String tempPrefix,
    required String tag,
    required String runnableLabel,
    required String createdAt,
    required String weakSpec,
    required String strongSpec,
    required bool strong,
    required List<GreeterBehavior> behaviors,
  }) async {
    final root = await Directory.systemTemp.createTemp(tempPrefix);
    final fx = ArenaGreeterFixture._(root: root, featureName: featureName);
    await fx._write(
      spec: strong ? strongSpec : weakSpec,
      strong: strong,
      behaviors: behaviors,
      tag: tag,
      runnableLabel: runnableLabel,
      createdAt: createdAt,
    );
    return fx;
  }

  // -- spec bodies -----------------------------------------------------

  static const String _arenaWeakSpec = '''
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

  static const String _arenaStrongSpec = '''
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

  static const String _greeterWeakSpec = '''
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
  traces: Greeter
- **FR-002**: The greeter MUST NOT fail when the name is empty.
  traces: Greeter
''';

  static const String _greeterStrongSpec = '''
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
  traces: Greeter
- **FR-002**: The greeter MUST return 0 when the name is empty; it MUST NOT return 42 in that case.
  traces: Greeter
''';

  // -- generators ------------------------------------------------------

  /// The gen-shaped generic unit test (no pins — the weak fixture).
  static String unitTest(
    String featureName,
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
import '../../../lib/tdd/$featureName/${id.toLowerCase()}_subject.dart' as subject;

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
    String featureName,
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
import '../../../lib/tdd/$featureName/${id.toLowerCase()}_subject.dart' as subject;

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
    String featureName,
    String id,
    String criterion,
    String description,
    String tag,
    int pin,
  ) =>
      '''
// GENERATED TEST — strengthened by the implementer to pin the declared
// code ($tag).
//
// behavior_id: $id
// source_criterion: $criterion
// description: $description
library;

import 'package:test/test.dart';
import '../../../lib/tdd/$featureName/${id.toLowerCase()}_subject.dart' as subject;

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
    String featureName,
    String id,
    String criterion,
    String description,
    String tag,
    int pin,
  ) =>
      '''
// GENERATED TEST — strengthened by the implementer to pin the declared
// code ($tag).
//
// behavior_id: $id
// source_criterion: $criterion
// description: $description
library;

import 'package:test/test.dart';
import '../../../lib/tdd/$featureName/${id.toLowerCase()}_subject.dart' as subject;

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

  static String subject(String tag, int value) =>
      '''
// IMPLEMENTED SUBJECT ($tag).
library;

int subjectUnderTest() => $value;
''';

  // -- the registry write ----------------------------------------------

  Future<void> _write({
    required String spec,
    required bool strong,
    required List<GreeterBehavior> behaviors,
    required String tag,
    required String runnableLabel,
    required String createdAt,
  }) async {
    await Directory(p.join(featureDir, 'tdd')).create(recursive: true);
    await File(p.join(featureDir, 'spec.md')).writeAsString(spec);

    for (final behavior in behaviors) {
      final description = strong
          ? behavior.strongDescription
          : behavior.weakDescription;
      final pin = strong ? behavior.pin : null;
      final isAcceptance = behavior.behaviorId.startsWith('A');
      final test = pin == null
          ? (isAcceptance
                ? acceptanceTest(
                    featureName,
                    behavior.behaviorId,
                    behavior.sourceCriterion,
                    description,
                  )
                : unitTest(
                    featureName,
                    behavior.behaviorId,
                    behavior.sourceCriterion,
                    description,
                  ))
          : (isAcceptance
                ? pinnedAcceptanceTest(
                    featureName,
                    behavior.behaviorId,
                    behavior.sourceCriterion,
                    description,
                    tag,
                    pin,
                  )
                : pinnedUnitTest(
                    featureName,
                    behavior.behaviorId,
                    behavior.sourceCriterion,
                    description,
                    tag,
                    pin,
                  ));
      await File(
        p.join(
          root.path,
          'test',
          'tdd',
          featureName,
          '${behavior.slug}_test.dart',
        ),
      ).create(recursive: true).then((f) => f.writeAsString(test));

      await File(
            p.join(
              root.path,
              'lib',
              'tdd',
              featureName,
              '${behavior.slug}_subject.dart',
            ),
          )
          .create(recursive: true)
          .then((f) => f.writeAsString(subject(tag, behavior.pin)));
    }

    final records = [
      for (final behavior in behaviors)
        {
          'behavior_id': behavior.behaviorId,
          'feature': featureName,
          'source_criterion': behavior.sourceCriterion,
          'test_path': 'test/tdd/$featureName/${behavior.slug}_test.dart',
          'subject_path': 'lib/tdd/$featureName/${behavior.slug}_subject.dart',
          'runnable_test_name': '${behavior.behaviorId} — $runnableLabel',
          'test_ownership': 'created',
          'subject_ownership': 'created',
          'created_at': createdAt,
        },
    ];
    await File(p.join(featureDir, 'tdd', 'artifacts.json')).writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'feature': featureName, 'records': records}),
    );
  }
}

/// The honest fake spawn shared by both spec-fuzz suites: reads the test
/// file the writer regenerated, extracts the `equals(<n>)` pin, and
/// compares it against the paired subject's return value — green when
/// they match, red otherwise.
///
/// A regenerated test without an `equals(<n>)` pin is green (the
/// writer's generic shape genuinely passes against implemented
/// subjects). A regenerated test with no subject import cannot be
/// writer-shaped — the real spawn fails to LOAD it, so the mock reports
/// a load failure (non-zero exit, `Failed to load`) and the auditor
/// grades that `not_assessed`: infrastructure is never a kill, never a
/// silent green.
Future<ProcessResult> fakeSpawn(
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
  if (subjectMatch == null) {
    // No subject import: the file cannot be writer-shaped — the real
    // spawn fails to load it and the auditor grades that not_assessed
    // (issue #1045's classification).
    return ProcessResult(
      42,
      253,
      'Failed to load "$testPath": no subject import',
      '',
    );
  }
  if (equals == null) {
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
