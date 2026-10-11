// Bug #1626 — the acceptance vacuous-green refusal prescribes the
// FR-traces remedy, which cannot produce a real acceptance assertion —
// the author hand step goes unnamed.
//
// On a fresh CORE spec the run stops at the first acceptance behavior
// with a `vacuous-green` refusal (the #1488 gate, working as designed)
// — but the remedy it prints (add `traces:` → re-plan → re-gen) CANNOT
// make an acceptance test non-vacuous: the acceptance lane ignores the
// contract shape by design (#1512 — "the contract-derived shape rides
// ONLY the plain-function pair (unit lane)"). Following the printed
// instructions loops; the path that actually works (hand-write the
// outcome assertion OUTSIDE the capture + implement the scenario runner
// + attestation header + `zfa tdd make <id> --born-green`, the #1411
// designed hand step — measured in the issue and documented by the
// repo's own fixture `bug_1488_acceptance_vacuous_green_test.dart`,
// helper `outcomeAssertedAcceptanceTest`) is never named.
//
// Remediation (issue #1626): messaging only — the #1488 gate, the #1512
// contract-shape ignore and the hand-step mechanics are untouched.
//
//   1. a shared wording builder in `vacuous_guard.dart`
//      (`acceptanceVacuousHandStepRemedyFor`) names the hand step with
//      the paths to BOTH files the author edits (test + subject);
//   2. the make-side refusal (step 3c) renders it for acceptance rows;
//   3. the run driver's make-vacuous-green marker-absent arm renders it
//      for acceptance rows (`stopped_at=<id>:make` preserved — the
//      honest fallback-routed class, #1512);
//   4. unit/fallback rows keep the existing wording everywhere (the
//      traces remedy WORKS there — criterion 3).
//
// Test map (this file — the make surface + the shared builder; the
// driver surface lives in bug_1626_acceptance_remedy_driver_test.dart):
//   U-1626-w1 — the shared builder renders the hand-step vocabulary:
//        outcome assertion OUTSIDE the capture, test path, scenario
//        runner subject path, attestation header, `--born-green`, the
//        #1512 why.
//   U-1626-a1 — `zfa tdd make` refuses an acceptance guard-only test
//        naming the hand step with BOTH paths (project-relative posix).
//   U-1626-a2 — the acceptance refusal no longer prescribes the
//        traces/re-plan/re-gen remedy.
//   U-1626-a3 — the unit-lane refusal is unchanged (contract
//        preservation): outcome-assertion wording, `marker if present`,
//        no hand-step vocabulary.
import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/born_green.dart';
import 'package:zuraffa/src/plugins/tdd/services/vacuous_guard.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  group('bug 1626 — the shared acceptance hand-step remedy wording', () {
    test('U-1626-w1: the builder names the hand step, both paths, the '
        'attestation header, --born-green, and the #1512 why', () {
      final remedy = acceptanceVacuousHandStepRemedyFor(
        behaviorId: 'A1',
        testPath: 'test/tdd/calculator/a1_test.dart',
        subjectPath: 'lib/tdd/calculator/a1_subject.dart',
      );

      // The hand step, in the issue's own vocabulary.
      expect(remedy, contains('write an assertion on the observable outcome'));
      expect(remedy, contains('OUTSIDE the capture'));
      // Both file paths (criterion 4) — the author must know where to edit.
      expect(remedy, contains('test/tdd/calculator/a1_test.dart'));
      expect(remedy, contains('lib/tdd/calculator/a1_subject.dart'));
      expect(remedy, contains('implement the scenario runner in'));
      // The attestation header (the exact #1411 line, copy-mechanical).
      expect(remedy, contains(handStepHeader('A1')));
      // The born-green certification command.
      expect(remedy, contains('`zfa tdd make A1 --born-green`'));
      // The WHY: traces/re-plan/re-gen cannot work here (#1512).
      expect(
        remedy,
        contains(
          'traces/re-plan/re-gen cannot produce a real '
          'acceptance assertion',
        ),
      );
      expect(remedy, contains('issue #1512'));
    });
  });

  group('bug 1626 — the make-side acceptance refusal (step 3c)', () {
    late TddFixture fx;

    setUp(() async {
      fx = await TddFixture.create();
    });

    tearDown(() {
      fx.dispose();
      exitCode = 0;
    });

    test('U-1626-a1: the acceptance refusal names the hand step with BOTH '
        'paths (test + subject)', () async {
      const description = 'the todo list renders the seeded items';
      await fx.seedTestList([
        (
          id: 'A1',
          description: description,
          traces: 'AC-9',
          state: 'PENDING',
          kind: 'acceptance',
        ),
      ]);
      await fx.seedCertifiedRed(
        id: 'A1',
        description: description,
        subjectContent: '''
library;

final List<String> scenarioSteps = <String>[];

void subject_a1() {
  scenarioSteps.add('scenario-step');
}
''',
        testContent:
            '''
import '../lib/a1_subject.dart' as subject;
import 'package:test/test.dart';

void main() {
  test('A1 — $description', () {
    final Object? result = (() {
      try {
        subject.subject_a1();
        return null;
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, isNot(isA<UnimplementedError>()));
  });
}
''',
      );

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'make', 'A1', '--project', fx.root.path]);

      // The refusal stands (the #1488 gate is untouched).
      expect(exitCode, 1, reason: 'a vacuous green must not certify: $out');
      expect(out, contains('outcome=vacuous-green'));
      expect(out, contains('issue #1488'));
      // THE FIX: the hand step is named, with both paths (criteria 2+4).
      expect(out, contains('OUTSIDE the capture'), reason: out);
      expect(out, contains('implement the scenario runner in'), reason: out);
      expect(
        out,
        contains('test/a1_test.dart'),
        reason: 'the refusal must name the test path: $out',
      );
      expect(
        out,
        contains('lib/a1_subject.dart'),
        reason: 'the refusal must name the subject path: $out',
      );
      expect(out, contains(handStepHeader('A1')), reason: out);
      expect(out, contains('`zfa tdd make A1 --born-green`'), reason: out);
    });

    test('U-1626-a2: the acceptance refusal no longer prescribes the '
        'traces/re-plan/re-gen remedy', () async {
      const description = 'the todo list renders the seeded items';
      await fx.seedTestList([
        (
          id: 'A1',
          description: description,
          traces: 'AC-9',
          state: 'PENDING',
          kind: 'acceptance',
        ),
      ]);
      await fx.seedCertifiedRed(
        id: 'A1',
        description: description,
        subjectContent: '''
library;

final List<String> scenarioSteps = <String>[];

void subject_a1() {
  scenarioSteps.add('scenario-step');
}
''',
        testContent:
            '''
import '../lib/a1_subject.dart' as subject;
import 'package:test/test.dart';

void main() {
  test('A1 — $description', () {
    final Object? result = (() {
      try {
        subject.subject_a1();
        return null;
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, isNot(isA<UnimplementedError>()));
  });
}
''',
      );

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'make', 'A1', '--project', fx.root.path]);

      expect(exitCode, 1, reason: out);
      // The looping remedy is GONE from the acceptance refusal: the
      // acceptance lane ignores the contract shape (#1512), so
      // traces/re-plan/re-gen provably cannot satisfy the #1488 gate.
      expect(out, isNot(contains('re-run zfa tdd plan')), reason: out);
      expect(out, isNot(contains('add traces:')), reason: out);
      expect(out, isNot(contains('hand-edit')), reason: out);
    });

    test('U-1626-a3: the unit-lane refusal is unchanged — outcome-assertion '
        'wording, `marker if present`, no hand-step vocabulary', () async {
      const description =
          'the system MUST save a Session when the form is committed';
      await fx.seedTestList([
        (
          id: 'U1',
          description: description,
          traces: 'FR-100',
          state: 'PENDING',
          kind: 'unit',
        ),
      ]);
      await fx.seedCertifiedRed(
        id: 'U1',
        description: description,
        subjectContent: '''
library;

int subject_u1() {
  return 0;
}
''',
        testContent:
            '''
import '../lib/u1_subject.dart' as subject;
import 'package:test/test.dart';

void main() {
  test('U1 — $description', () {
    final result = (() {
      try {
        return subject.subject_u1();
      } on UnimplementedError catch (error) {
        return error;
      }
    })();
    expect(result, isNot(isA<UnimplementedError>()));
  });
}
''',
      );

      final out = await CliRunner(
        exitOnCompletion: false,
      ).runCapturing(['tdd', 'make', 'U1', '--project', fx.root.path]);

      expect(exitCode, 1, reason: 'a vacuous green must not certify: $out');
      expect(out, contains('outcome=vacuous-green'));
      // The unit remedy is the outcome-assertion wording (where it WORKS:
      // the unit capture returns the subject's value) — untouched.
      expect(
        out,
        contains('add at least one assertion on the observable outcome'),
        reason: out,
      );
      expect(out, contains('marker if present'), reason: out);
      // No hand-step vocabulary leaks into the unit lane.
      expect(out, isNot(contains('OUTSIDE the capture')), reason: out);
      expect(
        out,
        isNot(contains('implement the scenario runner')),
        reason: out,
      );
      expect(out, isNot(contains('--born-green')), reason: out);
    });
  });
}
