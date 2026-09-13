@Tags(['slow'])
// Bug #1488 — the ACCEPTANCE lane certifies vacuous greens.
//
// An acceptance behavior is certified green by `zfa tdd make` when its
// assertion set is the UnimplementedError guard alone — the exact vacuity
// class issue #1259 was raised to eliminate. The detection logic
// (`contentIsVacuousGreen`, `vacuous_guard.dart`) correctly returns true
// for acceptance guard-only tests, but the make-side call site is gated
// on `BehaviorKind.unit` only: an acceptance row with a passing
// guard-only test reaches the drift/skip transition and certifies green
// (a proof-free success) instead of being refused.
//
// Why the gate MUST cover acceptance (post-#1512 composition reality):
// `tdd compose` implements the acceptance subject but NEVER touches the
// paired test file (the 044 ownership contract, `compose_command.dart`
// library doc) — so a guard-only acceptance test stays guard-only for
// its whole life and every green it certifies is proof-free. The run
// driver already carries the honest stop for this outcome
// (`run_driver_core.dart`: make `vacuous-green` → marker-absent
// fallback → `stopped_at=<id>:make`, issue #1308/#1512 classification);
// only the make gate was missing.
//
// Test map:
//   A1 — make refuses a PASSING guard-only acceptance test (the
//        composed/dummy subject class): exit 1, outcome=vacuous-green,
//        no green evidence. THE BUG. (Inverts the legacy-scope pin U3 of
//        bug_1259_vacuous_green_test.dart, which kept the refusal
//        unit-lane scoped by design pre-#1488.)
//   A2 — the same acceptance test WITH an observable-outcome assertion
//        still certifies green: the refusal keys on the assertion set,
//        never the lane.
//   A3 — kindless/legacy rows (no resolvable kind) keep the fail-open
//        skip transition: no test list kind cell → no refusal (the
//        #1259 fail-open contract is unchanged for legacy projects).
//   U1 — the unit lane refusal is byte-for-byte unchanged (issue #1259
//        U1 mirror): a guard-only unit test is still refused.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

/// The gen-emitted guard-only ACCEPTANCE test (issue #1512's fallback
/// shape, mirrored from bug_1259_vacuous_green_test.dart): the void-safe
/// capture + the UnimplementedError guard, nothing else.
String guardOnlyAcceptanceTest(String id, String description) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
import '../lib/${id.toLowerCase().replaceAll('-', '_')}_subject.dart' as subject;
import 'package:test/test.dart';

void main() {
  test('$id — $description', () {
    final Object? result = (() {
      try {
        subject.$symbol();
        return null;
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, isNot(isA<UnimplementedError>()));
  });
}
''';
}

/// The same acceptance test plus one observable-outcome assertion — the
/// shape green certification must REQUIRE (issue #1488 remediation).
/// The acceptance capture is void-safe by design (it returns null for
/// any non-throwing scenario runner), so the honest outcome assertion
/// here is on the completion surface: the runner returned, nothing
/// threw, the capture resolved null.
String outcomeAssertedAcceptanceTest(String id, String description) =>
    guardOnlyAcceptanceTest(id, description).replaceFirst(
      '    expect(result, isNot(isA<UnimplementedError>()));',
      '    expect(result, isNot(isA<UnimplementedError>()));\n'
          '    expect(result, isNull);',
    );

/// The gen-emitted guard-only UNIT test (the issue #1259 shape) — the
/// unit-lane mirror pin.
String guardOnlyTest(String id, String description) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
import '../lib/${id.toLowerCase().replaceAll('-', '_')}_subject.dart' as subject;
import 'package:test/test.dart';

void main() {
  test('$id — $description', () {
    final result = (() {
      try {
        return subject.$symbol();
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, isNot(isA<UnimplementedError>()));
  });
}
''';
}

/// An implemented acceptance scenario runner (no throw) — the composed /
/// func-scaffolded state the guard-only test vacuously passes against.
String scaffoldedVoidSubject(String id) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
library;

void $symbol() {}
''';
}

/// A func-scaffolded unit subject (the post-`tdd func` dummy class).
String scaffoldedUnitSubject(String id) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
library;

int $symbol() {
  return 0;
}
''';
}

void main() {
  late TddFixture fx;

  setUp(() async {
    fx = await TddFixture.create();
  });

  tearDown(() {
    fx.dispose();
    exitCode = 0;
  });

  group('issue #1488 — make refuses vacuous greens (acceptance lane)', () {
    test('A1: an acceptance test whose only assertion is the '
        'UnimplementedError guard cannot certify green — even when it '
        'passes', () async {
      const description = 'the todo list renders the seeded items';
      await fx.seedTestList([
        (
          id: 'A-1488',
          description: description,
          traces: 'AC-9',
          state: 'PENDING',
          kind: 'acceptance',
        ),
      ]);
      // The vacuous-green state the issue reports: certified red (the
      // stub threw), then the subject was implemented/scaffolded to a
      // non-throwing body — the guard-only acceptance test now PASSES
      // and the drift/skip transition certified it green pre-#1488.
      await fx.seedCertifiedRed(
        id: 'A-1488',
        description: description,
        subjectContent: scaffoldedVoidSubject('A-1488'),
        testContent: guardOnlyAcceptanceTest('A-1488', description),
      );

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'make', 'A-1488', '--project', fx.root.path]);

      expect(exitCode, 1, reason: 'a vacuous green must not certify: $out');
      expect(out, contains('outcome=vacuous-green'));
      expect(out, contains('UnimplementedError guard'));
      final log = await File(fx.cycleLogPath).readAsString();
      expect(
        log,
        isNot(contains('## Cycle: A-1488 (green)')),
        reason: 'no green evidence may be appended for a vacuous green',
      );
    });

    test('A2: the acceptance test WITH an observable-outcome assertion '
        'still certifies green — the refusal keys on the assertion set, '
        'not the lane', () async {
      const description = 'the todo list renders the seeded items';
      await fx.seedTestList([
        (
          id: 'A-1488',
          description: description,
          traces: 'AC-9',
          state: 'PENDING',
          kind: 'acceptance',
        ),
      ]);
      await fx.seedCertifiedRed(
        id: 'A-1488',
        description: description,
        subjectContent: scaffoldedVoidSubject('A-1488'),
        testContent: outcomeAssertedAcceptanceTest('A-1488', description),
      );

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'make', 'A-1488', '--project', fx.root.path]);

      expect(exitCode, 0, reason: 'out: $out');
      expect(out, contains('outcome=skipped'));
    });

    test('A3: kindless/legacy rows keep the fail-open skip transition — '
        'no resolvable kind, no refusal (the #1259 fail-open contract '
        'unchanged)', () async {
      const description = 'the legacy scenario completes';
      // No test list at all: the row's kind is unresolvable, exactly the
      // legacy-project shape _rowKindQuiet fails open for.
      await fx.seedCertifiedRed(
        id: 'A-9000',
        description: description,
        subjectContent: scaffoldedVoidSubject('A-9000'),
        testContent: guardOnlyAcceptanceTest('A-9000', description),
      );

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'make', 'A-9000', '--project', fx.root.path]);

      expect(exitCode, 0, reason: 'out: $out');
      expect(out, contains('outcome=skipped'));
    });

    test('U1: the unit lane refusal is unchanged — a guard-only unit '
        'test is still refused (issue #1259 U1 mirror)', () async {
      const description =
          'the system MUST save a Session when the form is committed';
      await fx.seedTestList([
        (
          id: 'U-1488',
          description: description,
          traces: 'FR-100',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.seedCertifiedRed(
        id: 'U-1488',
        description: description,
        subjectContent: scaffoldedUnitSubject('U-1488'),
        testContent: guardOnlyTest('U-1488', description),
      );

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'make', 'U-1488', '--project', fx.root.path]);

      expect(exitCode, 1, reason: 'a vacuous green must not certify: $out');
      expect(out, contains('outcome=vacuous-green'));
      final log = await File(fx.cycleLogPath).readAsString();
      expect(log, isNot(contains('## Cycle: U-1488 (green)')));
    });
  });
}
