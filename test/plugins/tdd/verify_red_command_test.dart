// Tests for the VerifyRedCommand (spec 046-tdd-verify-red, T008, T009,
// T010 — certified honest-red path; U23, U25, U27, A1-A3).
//
// Drives the public CLI surface (`zfa tdd verify-red`) against a real
// temp fixture project whose registry records gen-style artifacts; the
// runner executes a REAL `dart test` subprocess inside the fixture.
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

void main() {
  late TddFixture fx;
  late Directory prev;
  const description = 'returns 42 when invoked with no args';

  setUp(() async {
    prev = Directory.current;
    fx = await TddFixture.create();
    await fx.registerBehavior(id: 'B-001', description: description);
    Directory.current = fx.root;
  });

  tearDown(() {
    Directory.current = prev;
    fx.dispose();
    // The command signals rejection through dart:io `exitCode` (the
    // CliRunner honors it); reset between tests so each starts clean.
    exitCode = 0;
  });

  group('certified honest red (US1 / FR-001, FR-003, FR-006, FR-009)', () {
    test(
      'U23/A1: honest red certifies — exit 0, summary line, one complete entry',
      () async {
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(['tdd', 'verify-red', 'B-001']);

        // Machine-readable summary line (FR-009).
        expect(
          out,
          contains(
            'verify-red: behavior=B-001 classification=assertion '
            'certified=true feature=${fx.featureName}',
          ),
        );
        expect(exitCode, 0, reason: 'certified red must exit 0');

        // Exactly one red entry appended with ALL 8 contract fields.
        final log = await File(fx.cycleLogPath).readAsString();
        expect(log, contains('## Cycle: B-001 (red)'));
        expect(log, contains('- behavior: B-001'));
        expect(log, contains('- kind: red'));
        expect(log, contains('- classification: assertionFailure'));
        expect(log, contains('- criterion: FR-007'));
        expect(log, contains('- test: ${fx.testPathOf('B-001')}'));
        expect(log, contains('- exit: 1'));
        expect(RegExp(r'^- at: \d{4}-\d{2}-\d{2}T', multiLine: true)
            .hasMatch(log), isTrue);
        expect(log, contains('Expected:'));
        expect(log, contains('Actual:'));
        // The runner command recorded is the profile-resolved one.
        expect(log, contains('--plain-name "$description"'));
        // Exactly one entry for this run.
        expect('## Cycle: B-001 (red)'.allMatches(log), hasLength(1));
      },
    );

    test(
      'U25/A3: a certified run modifies no file under test/ or lib/',
      () async {
        final before = fx.checksumTestAndLib();
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing(['tdd', 'verify-red', 'B-001']);
        expect(fx.checksumTestAndLib(), equals(before));
      },
    );

    test(
      're-run on a certified behavior appends a second dated entry '
      '(append-only history, spec edge case)',
      () async {
        final runner = CliRunner(exitOnCompletion: false);
        await runner.runCapturing(['tdd', 'verify-red', 'B-001']);
        final first = await File(fx.cycleLogPath).readAsString();
        await runner.runCapturing(['tdd', 'verify-red', 'B-001']);
        final second = await File(fx.cycleLogPath).readAsString();

        expect(second.length, greaterThan(first.length));
        expect('## Cycle: B-001 (red)'.allMatches(second), hasLength(2));
        // The first entry is preserved verbatim (append-only).
        expect(second.startsWith(first), isTrue);
        expect(exitCode, 0);
      },
    );

    test(
      'U27: missing profile misfire-stops before any run, exit non-zero',
      () async {
        final profile =
            File('${fx.root.path}/.specify/memory/tdd-profile.md');
        profile.deleteSync();
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(['tdd', 'verify-red', 'B-001']);
        expect(out.toLowerCase(), contains('tdd-profile.md'));
        expect(
          out,
          contains(
            'verify-red: behavior=B-001 classification=unresolved '
            'certified=false feature=${fx.featureName}',
          ),
        );
        expect(exitCode, isNot(0));
        // No evidence written.
        expect(File(fx.cycleLogPath).existsSync(), isFalse);
      },
    );
  });
}
