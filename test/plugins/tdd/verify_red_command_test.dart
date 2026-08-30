@Tags(['slow'])
// Tests for the VerifyRedCommand (spec 046-tdd-verify-red, T008, T009,
// T010 — certified honest-red path; U23, U25, U27, A1-A3).
//
// Drives the public CLI surface (`zfa tdd verify-red`) against a real
// temp fixture project whose registry records gen-style artifacts; the
// runner executes a REAL `dart test` subprocess inside the fixture.
//
// The fixture root is passed explicitly via `--project`, so this suite
// never mutates the process-global Directory.current (which concurrent
// test files share and can corrupt).
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:test/test.dart';
import 'package:zuraffa/src/cli/cli_runner.dart';

import 'helpers/tdd_fixture.dart';

/// Build the CLI args for `zfa tdd verify-red`, pinning the project root so
/// the command resolves specs/test/.specify under [fx] without depending on
/// Directory.current.
List<String> verifyRedArgs(TddFixture fx, [String? id]) => [
  'tdd',
  'verify-red',
  '--project',
  fx.root.path,
  if (id != null) id,
];

void main() {
  late TddFixture fx;
  const description = 'returns 42 when invoked with no args';

  setUp(() async {
    fx = await TddFixture.create();
    await fx.registerBehavior(id: 'B-001', description: description);
  });

  tearDown(() {
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
        final out = await runner.runCapturing(verifyRedArgs(fx, 'B-001'));

        // Machine-readable summary line (FR-009).
        expect(
          out,
          contains(
            'verify-red: behavior=B-001 classification=assertion '
            'certified=true feature=${fx.featureName}',
          ),
        );
        expect(exitCode, 0, reason: 'certified red must exit 0');

        // Nine serialized fields: 8 evidence fields plus structural `kind`.
        final log = await File(fx.cycleLogPath).readAsString();
        expect(log, contains('## Cycle: B-001 (red)'));
        expect(log, contains('- behavior: B-001'));
        expect(log, contains('- kind: red'));
        expect(log, contains('- classification: assertionFailure'));
        expect(log, contains('- criterion: FR-007'));
        expect(log, contains('- test: ${fx.testPathOf('B-001')}'));
        expect(log, contains('- exit: 1'));
        expect(
          RegExp(r'^- at: \d{4}-\d{2}-\d{2}T', multiLine: true).hasMatch(log),
          isTrue,
        );
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
        await runner.runCapturing(verifyRedArgs(fx, 'B-001'));
        expect(fx.checksumTestAndLib(), equals(before));
      },
    );

    test(
      'U25: a mutating assertion failure is rejected without red evidence',
      () async {
        await File(
          fx.testPathOf('B-001'),
        ).writeAsString(TddFixture.mutatingRedTest(description));
        final runner = CliRunner(exitOnCompletion: false);

        final out = await runner.runCapturing(verifyRedArgs(fx, 'B-001'));

        expect(out, contains('read-only integrity violation'));
        expect(out, contains('lib/verify_red_mutation.txt'));
        expect(out, contains('test/verify_red_mutation.txt'));
        expect(
          out,
          contains(
            'verify-red: behavior=B-001 classification=runner-error '
            'certified=false feature=${fx.featureName}',
          ),
        );
        expect(exitCode, isNot(0));
        expect(File(fx.cycleLogPath).existsSync(), isFalse);
      },
    );

    test('re-run on a certified behavior appends a second dated entry '
        '(append-only history, spec edge case)', () async {
      final runner = CliRunner(exitOnCompletion: false);
      await runner.runCapturing(verifyRedArgs(fx, 'B-001'));
      final first = await File(fx.cycleLogPath).readAsString();
      await runner.runCapturing(verifyRedArgs(fx, 'B-001'));
      final second = await File(fx.cycleLogPath).readAsString();

      expect(second.length, greaterThan(first.length));
      expect('## Cycle: B-001 (red)'.allMatches(second), hasLength(2));
      // The first entry is preserved verbatim (append-only).
      expect(second.startsWith(first), isTrue);
      expect(exitCode, 0);
    });

    test(
      'U27: missing profile misfire-stops before any run, exit non-zero',
      () async {
        final profile = File('${fx.root.path}/.specify/memory/tdd-profile.md');
        profile.deleteSync();
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(verifyRedArgs(fx, 'B-001'));
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

  /// Shared body for the dishonest-red matrix (US2 / T012): a rejected run
  /// exits non-zero, names the class, and leaves the cycle log untouched.
  Future<void> expectRejection({
    required TddFixture fx,
    required String id,
    required String classification,
    bool logExistedBefore = false,
  }) async {
    final runner = CliRunner(exitOnCompletion: false);
    final String? logBefore = logExistedBefore
        ? await File(fx.cycleLogPath).readAsString()
        : null;
    final checksumsBefore = fx.checksumTestAndLib();

    final out = await runner.runCapturing(verifyRedArgs(fx, id));
    expect(
      out,
      contains(
        'verify-red: behavior=$id classification=$classification '
        'certified=false feature=${fx.featureName}',
      ),
      reason: 'summary line must name the class: got:\n$out',
    );
    expect(exitCode, isNot(0), reason: '$classification must exit non-zero');
    // The named class is also printed as a diagnostic line.
    expect(out, contains('classification: $classification'));

    // No evidence written: byte-identical (or still absent).
    if (logExistedBefore) {
      expect(await File(fx.cycleLogPath).readAsString(), logBefore);
    } else {
      expect(File(fx.cycleLogPath).existsSync(), isFalse);
    }
    // Read-only over test/ and lib/ on rejections too.
    expect(fx.checksumTestAndLib(), checksumsBefore);
  }

  group('dishonest-red rejection matrix (US2 / FR-004, FR-005, FR-007)', () {
    test('A4: compile-broken test -> compile-error, no evidence', () async {
      final fx2 = await TddFixture.create();
      try {
        await fx2.registerBehavior(
          id: 'B-001',
          description: description,
          testContent: TddFixture.compileErrorTest(description),
        );
        await expectRejection(
          fx: fx2,
          id: 'B-001',
          classification: 'compile-error',
        );
      } finally {
        fx2.dispose();
        exitCode = 0;
      }
    });

    test('A5: registry points at a missing file -> load-error', () async {
      final fx2 = await TddFixture.create();
      try {
        await fx2.registerBehavior(
          id: 'B-001',
          description: description,
          writeTestFile: false,
        );
        await expectRejection(
          fx: fx2,
          id: 'B-001',
          classification: 'load-error',
        );
      } finally {
        fx2.dispose();
        exitCode = 0;
      }
    });

    test('A6: passing target test -> unexpected-green', () async {
      final fx2 = await TddFixture.create();
      try {
        await fx2.registerBehavior(
          id: 'B-001',
          description: description,
          testContent: TddFixture.greenTest(description),
        );
        await expectRejection(
          fx: fx2,
          id: 'B-001',
          classification: 'unexpected-green',
        );
      } finally {
        fx2.dispose();
        exitCode = 0;
      }
    });

    test('A7: skipped target test -> skipped', () async {
      final fx2 = await TddFixture.create();
      try {
        await fx2.registerBehavior(
          id: 'B-001',
          description: description,
          testContent: TddFixture.skippedTest(description),
        );
        await expectRejection(fx: fx2, id: 'B-001', classification: 'skipped');
      } finally {
        fx2.dispose();
        exitCode = 0;
      }
    });

    test(
      'A8a: blended run (two tests match the filter) -> runner-error',
      () async {
        final fx2 = await TddFixture.create();
        try {
          // The registry name is a substring of BOTH tests in the file, so
          // the single-test filter matches two tests.
          await fx2.registerBehavior(
            id: 'B-001',
            description: 'returns 42',
            testContent: TddFixture.blendedTest(
              'returns 42 when invoked with no args',
              'returns 42 when invoked with some args',
            ),
          );
          await expectRejection(
            fx: fx2,
            id: 'B-001',
            classification: 'runner-error',
          );
        } finally {
          fx2.dispose();
          exitCode = 0;
        }
      },
    );

    test(
      'A8b: runner cannot launch (broken profile command) -> runner-error',
      () async {
        final fx2 = await TddFixture.create(
          singleTemplate:
              'definitely_not_a_real_binary_xyz {file} --plain-name "{name}"',
        );
        try {
          await fx2.registerBehavior(id: 'B-001', description: description);
          await expectRejection(
            fx: fx2,
            id: 'B-001',
            classification: 'runner-error',
          );
        } finally {
          fx2.dispose();
          exitCode = 0;
        }
      },
    );

    test(
      'U24: a rejected run leaves an existing cycle-log byte-identical',
      () async {
        final fx2 = await TddFixture.create();
        try {
          await fx2.registerBehavior(id: 'B-001', description: description);
          await fx2.registerBehavior(
            id: 'B-002',
            description: description,
            testContent: TddFixture.greenTest(description),
          );
          // Seed prior evidence so the log exists with content.
          await fx2.seedRedEvidence('B-001');
          final before = await File(fx2.cycleLogPath).readAsString();

          final runner = CliRunner(exitOnCompletion: false);
          await runner.runCapturing(verifyRedArgs(fx2, 'B-002'));
          expect(exitCode, isNot(0));
          expect(await File(fx2.cycleLogPath).readAsString(), before);
        } finally {
          fx2.dispose();
          exitCode = 0;
        }
      },
    );
  });

  group('target resolution (US3 / FR-001, FR-002, SC-004)', () {
    test('U18: unknown id errors naming the id BEFORE any run '
        '(works even with no profile present)', () async {
      final fx2 = await TddFixture.create();
      try {
        // No profile: if the command tried to run anything it would
        // misfire on the missing profile instead — so seeing the
        // unknown-id error proves resolution happens first.
        File('${fx2.root.path}/.specify/memory/tdd-profile.md').deleteSync();
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(verifyRedArgs(fx2, 'B-999'));
        expect(out, contains('B-999'));
        expect(out, contains('unknown behavior id'));
        expect(
          out,
          contains(
            'verify-red: behavior=B-999 classification=unresolved '
            'certified=false',
          ),
        );
        expect(exitCode, isNot(0));
      } finally {
        fx2.dispose();
        exitCode = 0;
      }
    });

    test(
      'U19: no-arg with exactly one uncertified gen\'d behavior verifies it',
      () async {
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(verifyRedArgs(fx));
        expect(
          out,
          contains(
            'verify-red: behavior=B-001 classification=assertion '
            'certified=true feature=${fx.featureName}',
          ),
        );
        expect(exitCode, 0);
        final log = await File(fx.cycleLogPath).readAsString();
        expect(log, contains('## Cycle: B-001 (red)'));
      },
    );

    test(
      'U20: no-arg with multiple uncertified behaviors lists the candidates',
      () async {
        await fx.registerBehavior(id: 'B-002', description: description);
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(verifyRedArgs(fx));
        expect(out, contains('ambiguous'));
        expect(out, contains('B-001'));
        expect(out, contains('B-002'));
        expect(
          out,
          contains(
            'verify-red: behavior=- classification=unresolved '
            'certified=false feature=unknown',
          ),
        );
        expect(exitCode, isNot(0));
        // No evidence for either candidate.
        expect(File(fx.cycleLogPath).existsSync(), isFalse);
      },
    );

    test('U21: no-arg with zero candidates states that none exist', () async {
      final fx2 = await TddFixture.create();
      try {
        // Registry exists but every behavior already has red evidence.
        await fx2.registerBehavior(id: 'B-001', description: description);
        await fx2.seedRedEvidence('B-001');
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(verifyRedArgs(fx2));
        expect(out, contains('no behavior with gen artifacts'));
        expect(exitCode, isNot(0));
      } finally {
        fx2.dispose();
        exitCode = 0;
      }
    });

    test(
      'U22: known test-list id without registry artifacts instructs gen first',
      () async {
        // Seed a test list row for B-777 in the fixture feature, with no
        // artifacts.json record for it.
        await File(p.join(fx.featureDir, 'tdd', 'test-list.md')).writeAsString(
          '''
# Test List

| id | behavior | traces | kind | state | target |
|----|----------|--------|------|-------|--------|
| B-777 | planned but not generated | FR-007 | unit | PENDING | x |
''',
        );
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(verifyRedArgs(fx, 'B-777'));
        expect(out, contains('B-777'));
        expect(out, contains('zfa tdd gen B-777'));
        expect(exitCode, isNot(0));
      },
    );

    test(
      'SC-004: ambiguous id across features fails with the candidate list',
      () async {
        // A SECOND feature directory inside the SAME project, so the
        // command's registry scan sees two records for B-001.
        const otherFeature = '091-other-fixture';
        final otherDir = p.join(fx.root.path, 'specs', otherFeature);
        await Directory(p.join(otherDir, 'tdd')).create(recursive: true);
        await File(p.join(otherDir, 'tdd', 'artifacts.json')).writeAsString(
          '{"feature":"$otherFeature","records":[{"behavior_id":"B-001",'
          '"feature":"$otherFeature","source_criterion":"FR-007",'
          '"test_path":"${fx.testPathOf('B-001')}",'
          '"subject_path":"lib/b_001_subject.dart",'
          '"runnable_test_name":"${fx.testPathOf('B-001')}::B-001::$description",'
          '"test_ownership":"created","subject_ownership":"created",'
          '"created_at":"2026-08-30T00:00:00.000Z"}]}',
        );
        final runner = CliRunner(exitOnCompletion: false);
        final out = await runner.runCapturing(verifyRedArgs(fx, 'B-001'));
        expect(out, contains('ambiguous'));
        expect(out, contains(fx.featureName));
        expect(out, contains(otherFeature));
        expect(exitCode, isNot(0));
        // No evidence written for either candidate.
        expect(File(fx.cycleLogPath).existsSync(), isFalse);
      },
    );
  });

  group('U26 — summary-line contract (US4 / FR-009, T016)', () {
    final shape = RegExp(
      r'^verify-red: behavior=(\S+) classification=(\S+) '
      r'certified=(true|false) feature=(\S+)$',
    );

    test(
      'certified and rejected runs both emit the pinned line format',
      () async {
        final runner = CliRunner(exitOnCompletion: false);
        final certified = await runner.runCapturing(verifyRedArgs(fx, 'B-001'));
        final certifiedLine = certified.trim().split('\n').last;
        final m1 = shape.firstMatch(certifiedLine);
        expect(m1, isNotNull, reason: 'line: \$certifiedLine');
        expect(m1!.group(3), 'true');

        // Rejected run: unknown id (no subprocess cost).
        final rejected = await runner.runCapturing(verifyRedArgs(fx, 'B-999'));
        final rejectedLine = rejected.trim().split('\n').last;
        final m2 = shape.firstMatch(rejectedLine);
        expect(m2, isNotNull, reason: 'line: \$rejectedLine');
        expect(m2!.group(2), 'unresolved');
        expect(m2.group(3), 'false');
      },
    );
  });
}
