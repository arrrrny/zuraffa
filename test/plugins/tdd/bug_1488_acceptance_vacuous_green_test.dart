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
//   A4 — the remediation proven against the artifact `gen` ACTUALLY
//        emits: gen's guard-only acceptance test → make refuses with the
//        hand-step remedy (#1626) → an assertion outside the capture
//        lands → make certifies green.
//   U1 — the unit lane refusal is byte-for-byte unchanged (issue #1259
//        U1 mirror): a guard-only unit test is still refused.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/born_green.dart';

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
/// any non-throwing scenario runner), so `expect(result, isNull)` would
/// only RESTATE the guard above it — that is the tautology review #1595
/// rejected. The honest assertion has to reach OUTSIDE the capture, at
/// the state the composed scenario writes: the void runner exposes no
/// value of its own, which is exactly what the lane's refusal message
/// must therefore not prescribe.
String outcomeAssertedAcceptanceTest(String id, String description) =>
    guardOnlyAcceptanceTest(id, description).replaceFirst(
      '    expect(result, isNot(isA<UnimplementedError>()));',
      '    expect(result, isNot(isA<UnimplementedError>()));\n'
          '    expect(subject.scenarioSteps, isNotEmpty);',
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

/// An implemented acceptance scenario runner (no throw) that RECORDS the
/// scenario step it executed — the composed / func-scaffolded state the
/// guard-only test vacuously passes against, and the observable state an
/// honest outcome assertion reaches (the void capture exposes no value).
String scaffoldedVoidSubject(String id) {
  final symbol = 'subject_${id.toLowerCase().replaceAll('-', '_')}';
  return '''
library;

final List<String> scenarioSteps = <String>[];

void $symbol() {
  scenarioSteps.add('scenario-step');
}
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
      expect(out, contains('issue #1488'));
      // Issue #1626: the acceptance refusal names the HAND STEP — the
      // traces/re-plan/re-gen remedy it used to print provably loops
      // (the acceptance lane ignores the contract shape, issue #1512),
      // so the working path is now the named one: an assertion on the
      // observable outcome OUTSIDE the capture, the scenario runner
      // implemented in the subject, the attestation header, and the
      // born-green certification — with BOTH file paths.
      expect(
        out,
        contains('OUTSIDE the capture'),
        reason: 'the acceptance remedy names the hand step: $out',
      );
      expect(
        out,
        contains('implement the scenario runner in'),
        reason: 'the acceptance remedy names the scenario runner: $out',
      );
      expect(
        out,
        contains('test/a_1488_test.dart'),
        reason: 'the refusal names the test path: $out',
      );
      expect(
        out,
        contains('lib/a_1488_subject.dart'),
        reason: 'the refusal names the subject path: $out',
      );
      expect(out, contains(handStepHeader('A-1488')), reason: out);
      expect(
        out,
        contains('`zfa tdd make A-1488 --born-green`'),
        reason: 'the refusal names the born-green certification: $out',
      );
      expect(
        out,
        isNot(contains('re-run zfa tdd plan')),
        reason:
            'the traces remedy provably loops on the acceptance lane '
            '(issue #1626) — it must be gone: $out',
      );
      expect(
        out,
        isNot(contains('marker if present')),
        reason:
            'the acceptance fallback deliberately carries no vacuous-guard '
            'marker (issue #1512) — the remedy must not tell the author to '
            'remove one: $out',
      );
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

    test('A4: the remedy proves out against the artifact `gen` emits — the '
        'generated guard-only acceptance test is refused, and an assertion '
        'outside the capture then certifies green', () async {
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

      // 1. The artifact gen ACTUALLY emits for an acceptance row with no
      //    declared contract shape: the guard-only acceptance fallback —
      //    the #1512 shape the #1488 gate now intercepts. (A1/A2/A3 seed
      //    the paired test by hand; this pin never does.)
      final genOut = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'gen', 'A-1488', '--project', fx.root.path]);
      expect(exitCode, 0, reason: 'gen out: $genOut');
      // The registry record is the single path contract: gen owns the
      // layout (project-relative, `test/tdd/<feature>/...`), so both
      // generated files are addressed through it.
      final record = await fx.registryRecordOf('A-1488');
      final genTestPath = p.join(fx.root.path, record['test_path'] as String);
      final genSubjectPath = p.join(
        fx.root.path,
        record['subject_path'] as String,
      );
      final generated = await File(genTestPath).readAsString();
      expect(
        generated,
        contains('expect(result, isNot(isA<UnimplementedError>()))'),
        reason: 'the emitted fallback carries the guard alone: $generated',
      );
      expect(
        generated,
        contains('acceptance-guard'),
        reason: 'the emitted test is the ACCEPTANCE fallback: $generated',
      );
      expect(
        generated,
        isNot(contains('scenarioSteps')),
        reason: 'nothing outside the capture is asserted yet',
      );
      // The honest red the generated pair starts from (the stub throws).
      await fx.seedRedEvidence('A-1488');

      // 2. make refuses the generated artifact itself — with the #1626
      //    hand-step remedy (the acceptance refusal of the gen-emitted
      //    fallback names the working path, not the looping traces one).
      final refused = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'make', 'A-1488', '--project', fx.root.path]);
      expect(exitCode, 1, reason: 'refusal out: $refused');
      expect(refused, contains('outcome=vacuous-green'));
      expect(refused, contains('OUTSIDE the capture'), reason: refused);
      expect(
        refused,
        contains('implement the scenario runner in'),
        reason: refused,
      );
      expect(
        refused,
        contains('lib/tdd/090-tdd-fixture/a_1488_subject.dart'),
        reason: 'the refusal names the gen-recorded subject path: $refused',
      );
      expect(
        refused,
        contains('`zfa tdd make A-1488 --born-green`'),
        reason: refused,
      );
      expect(
        refused,
        isNot(contains('re-run zfa tdd gen')),
        reason: 'the looping traces remedy is gone (issue #1626): $refused',
      );

      // 3. The prescribed remedy applied by hand: the scenario runner
      //    implemented (what the composition lane lands) and ONE assertion
      //    outside the capture added to the gen-emitted test — green. The
      //    symbol is read from gen's OWN call site in the emitted test (the
      //    stub's prose mentions other identifiers, so the subject text is
      //    not the source of truth).
      final generatedSubject = await File(genSubjectPath).readAsString();
      expect(
        generatedSubject,
        contains('UnimplementedError'),
        reason: 'the emitted subject is the honest-red stub: $generatedSubject',
      );
      final symbol = RegExp(
        r'subject\.(\w+)\s*\(',
      ).firstMatch(generated)!.group(1)!;
      await File(genSubjectPath).writeAsString('''
library;

final List<String> scenarioSteps = <String>[];

void $symbol() {
  scenarioSteps.add('scenario-step');
}
''');
      await File(genTestPath).writeAsString(
        generated.replaceFirst(
          'expect(result, isNot(isA<UnimplementedError>()));',
          'expect(result, isNot(isA<UnimplementedError>()));\n'
              '    expect(subject.scenarioSteps, isNotEmpty);',
        ),
      );
      final green = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'make', 'A-1488', '--project', fx.root.path]);
      expect(exitCode, 0, reason: 'green out: $green');
      expect(green, contains('outcome=skipped'));
    });

    test('A3: kindless/legacy rows keep the fail-open skip transition — '
        'no resolvable kind, no refusal (the #1259 fail-open contract '
        'unchanged)', () async {
      const description = 'the legacy scenario completes';
      // No test list AT ALL — not a row whose kind cell is empty: the
      // behavior has no row, so there is no kind cell to read at all. That
      // is the shape _rowKindQuiet fails open for; the row-present-with-kind
      // variants are pinned by bug_1259's U3 (acceptance) and U1 (unit).
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
