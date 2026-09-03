// Bug #805 — generator differential testing (vision slice v0).
//
// The ref runner drives one corpus entry against one materialized
// generator ref and records the behavioral result vector. These tests
// pin: ref resolution via git, worktree materialization/removal, the
// per-step outcome classification (exit 0 = complete, non-zero =
// failed, deadline hit = hang — the #744 class), machine-token
// extraction from the step commands' summary contracts, dart-test
// pass/fail count extraction, and the artifact inventory walk.
//
// All subprocesses are fakes (the #049/#051 injectable-spawner
// pattern); the real-spawn path is exercised end-to-end separately.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/models/differential_vector.dart';
import 'package:zuraffa/src/plugins/tdd/services/differential_corpus.dart';
import 'package:zuraffa/src/plugins/tdd/services/differential_ref_runner.dart';
import 'package:zuraffa/src/plugins/tdd/services/tdd_timeout.dart';

ProcessResult ok(String stdout) => ProcessResult(1, 0, stdout, '');
ProcessResult fail(String stdout, [String stderr = '']) =>
    ProcessResult(2, 1, stdout, stderr);

void main() {
  late Directory temp;
  late Directory repoRoot;
  late Directory scratch;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('diff_runner_');
    repoRoot = Directory(p.join(temp.path, 'repo'))..createSync();
    scratch = Directory(p.join(temp.path, 'scratch'))..createSync();
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  group('resolveRef', () {
    test('returns the trimmed commit sha on success', () async {
      final runner = DifferentialRefRunner(
        gitRunner: (args, cwd) async {
          expect(args[0], 'rev-parse');
          expect(args[1], '--verify');
          expect(args.join(' '), contains('HEAD'));
          return ok(' abc123def \n');
        },
      );
      expect(
        await runner.resolveRef('HEAD', repoRoot: repoRoot.path),
        'abc123def',
      );
    });

    test('an unknown ref is the distinct ref failure, never a crash', () async {
      final runner = DifferentialRefRunner(
        gitRunner: (args, cwd) async => fail('', 'fatal: not a ref'),
      );
      await expectLater(
        () => runner.resolveRef('nope', repoRoot: repoRoot.path),
        throwsA(isA<DifferentialRefException>()),
      );
    });
  });

  group('worktrees', () {
    test(
      'materializeWorktree adds a detached worktree and returns its path',
      () async {
        final parent = Directory(p.join(temp.path, 'wts'))..createSync();
        final runner = DifferentialRefRunner(
          gitRunner: (args, cwd) async {
            expect(args[0], 'worktree');
            expect(args[1], 'add');
            expect(args[2], '--detach');
            Directory(args[3]).createSync(recursive: true);
            return ok('');
          },
        );
        final wt = await runner.materializeWorktree(
          ref: 'abc123',
          repoRoot: repoRoot.path,
          parent: parent,
          name: 'wt-from',
        );
        expect(p.basename(wt), 'wt-from');
        expect(Directory(wt).existsSync(), isTrue);
      },
    );

    test('removeWorktree forces removal through git', () async {
      final recorded = <String>[];
      final runner = DifferentialRefRunner(
        gitRunner: (args, cwd) async {
          recorded.add(args.join(' '));
          return ok('');
        },
      );
      await runner.removeWorktree(path: '/tmp/wt-x', repoRoot: repoRoot.path);
      expect(recorded.single, contains('worktree remove --force /tmp/wt-x'));
    });

    test(
      'setupWorktree runs pub get and maps failure to a setup exception',
      () async {
        final runner = DifferentialRefRunner(
          spawner: (command, cwd) async {
            expect(command, ['dart', 'pub', 'get', '--no-example']);
            return fail('', 'resolution failed');
          },
        );
        await expectLater(
          () => runner.setupWorktree('/tmp/wt-x'),
          throwsA(isA<DifferentialSetupException>()),
        );
      },
    );
  });

  group('runEntry', () {
    late Directory scaffold;

    setUp(() async {
      scaffold = Directory(p.join(temp.path, 'scaffold'))
        ..createSync(recursive: true);
      File(
        p.join(scaffold.path, 'pubspec.yaml'),
      ).writeAsStringSync('name: u2_flow\n');
      Directory(
        p.join(scaffold.path, 'specs', 'u2-flow', 'tdd'),
      ).createSync(recursive: true);
    });

    DifferentialRefRunner runnerWith(
      Future<ProcessResult> Function(List<String> command, String cwd) fake,
    ) => DifferentialRefRunner(spawner: fake);

    test(
      'a healthy run records complete steps, tokens, and artifacts',
      () async {
        final runner = runnerWith((command, cwd) async {
          final argv = command.join(' ');
          if (argv.startsWith('dart pub get')) return ok('Got dependencies!');
          if (argv.contains('bin/zfa.dart') && argv.contains(' gen U1 ')) {
            return ok(
              'behavior_id: U1\n'
              '{"behaviorId":"U1","verdict":"created"}\n',
            );
          }
          if (argv.contains('bin/zfa.dart') && argv.contains(' gen U2 ')) {
            return ok(
              'behavior_id: U2\n'
              '{"behaviorId":"U2","verdict":"created"}\n',
            );
          }
          throw StateError('unexpected spawn: $argv');
        });

        // Pre-existing generated-pair state in the scaffold: the inventory
        // walks paths, not bytes (issue #805: "artifact inventory").
        Directory(
          p.join(scaffold.path, 'lib', 'tdd'),
        ).createSync(recursive: true);
        Directory(
          p.join(scaffold.path, 'test', 'tdd'),
        ).createSync(recursive: true);
        File(
          p.join(scaffold.path, 'test', 'tdd', 'u1_test.dart'),
        ).writeAsStringSync('void main() {}');
        File(
          p.join(scaffold.path, 'lib', 'tdd', 'u1.dart'),
        ).writeAsStringSync('void main() {}');

        final real = DifferentialEntry(
          name: 'u2-flow',
          incident: 744,
          description: 'test entry',
          steps: [
            DifferentialStepSpec(
              argv: ['tdd', 'gen', 'U1', '--feature', 'u2-flow'],
            ),
            DifferentialStepSpec(
              argv: ['tdd', 'gen', 'U2', '--feature', 'u2-flow'],
            ),
          ],
          artifactRoots: const ['test/tdd', 'lib/tdd'],
          projectDir: scaffold.path,
        );

        final vector = await runner.runEntry(
          entry: real,
          ref: 'HEAD',
          worktreePath: p.join(temp.path, 'wt'),
          scratch: scratch,
        );

        expect(vector.entry, 'u2-flow');
        expect(vector.ref, 'HEAD');
        expect(
          vector.steps.map((s) => s.outcome),
          everyElement(DifferentialStepOutcome.complete),
        );
        expect(vector.steps.map((s) => s.token), ['created', 'created']);
        expect(
          vector.artifacts,
          containsAllInOrder(['lib/tdd/u1.dart', 'test/tdd/u1_test.dart']),
          reason: 'the inventory is sorted relative paths',
        );
        // The scratch project is a real copy of the scaffold, driven in place.
        expect(
          File(
            p.join(
              scratch.path,
              'project',
              'specs',
              'u2-flow',
              'tdd',
              'placeholder',
            ),
          ).existsSync(),
          isFalse,
        );
        expect(
          File(p.join(scratch.path, 'project', 'pubspec.yaml')).existsSync(),
          isTrue,
        );
      },
    );

    test(
      'a non-zero step is the failed outcome with its machine token',
      () async {
        final runner = runnerWith((command, cwd) async {
          final argv = command.join(' ');
          if (argv.startsWith('dart pub get')) return ok('Got dependencies!');
          if (argv.contains(' make U1 ')) {
            return fail('Something failed\n', 'boom');
          }
          throw StateError('unexpected spawn: $argv');
        });
        final real = DifferentialEntry(
          name: 'e',
          incident: null,
          description: 'd',
          steps: [
            DifferentialStepSpec(
              argv: ['tdd', 'make', 'U1', '--suite-baseline', '.zfa/b.json'],
            ),
          ],
          artifactRoots: const ['test/tdd'],
          projectDir: scaffold.path,
        );
        final vector = await runner.runEntry(
          entry: real,
          ref: 'a',
          worktreePath: p.join(temp.path, 'wt'),
          scratch: scratch,
        );
        expect(vector.steps.single.outcome, DifferentialStepOutcome.failed);
        expect(vector.steps.single.exitCode, 1);
      },
    );

    test(
      'a deadline hit is the hang outcome (the #744 class), exit -1',
      () async {
        final runner = runnerWith((command, cwd) async {
          final argv = command.join(' ');
          if (argv.startsWith('dart pub get')) return ok('Got dependencies!');
          if (argv.contains(' gen U2 ')) {
            throw ProcessTimeoutException(
              executable: 'dart',
              arguments: const [],
              timeout: const Duration(seconds: 1),
              workingDirectory: cwd,
              output: '',
            );
          }
          return ok('{"behaviorId":"U1","verdict":"created"}\n');
        });
        final real = DifferentialEntry(
          name: 'e',
          incident: 744,
          description: 'd',
          steps: [
            DifferentialStepSpec(
              argv: ['tdd', 'gen', 'U1', '--feature', 'u2-flow'],
            ),
            DifferentialStepSpec(
              argv: ['tdd', 'gen', 'U2', '--feature', 'u2-flow'],
            ),
          ],
          artifactRoots: const ['test/tdd'],
          projectDir: scaffold.path,
        );
        final vector = await runner.runEntry(
          entry: real,
          ref: 'broken',
          worktreePath: p.join(temp.path, 'wt'),
          scratch: scratch,
        );
        expect(vector.steps.first.outcome, DifferentialStepOutcome.complete);
        expect(vector.steps.last.outcome, DifferentialStepOutcome.hang);
        expect(vector.steps.last.exitCode, -1);
        expect(vector.outcomeSummary, 'complete, hang');
      },
    );

    test(
      'a make step extracts its outcome label from the summary line',
      () async {
        final runner = runnerWith((command, cwd) async {
          final argv = command.join(' ');
          if (argv.startsWith('dart pub get')) return ok('Got dependencies!');
          if (argv.contains(' make U1 ')) {
            return ok('make: behavior=U1 outcome=pass feature=u2-flow\n');
          }
          throw StateError('unexpected spawn: $argv');
        });
        final real = DifferentialEntry(
          name: 'e',
          incident: 751,
          description: 'd',
          steps: [
            DifferentialStepSpec(argv: ['tdd', 'make', 'U1']),
          ],
          artifactRoots: const ['test/tdd'],
          projectDir: scaffold.path,
        );
        final vector = await runner.runEntry(
          entry: real,
          ref: 'HEAD',
          worktreePath: p.join(temp.path, 'wt'),
          scratch: scratch,
        );
        expect(vector.steps.single.token, 'pass');
      },
    );

    test(
      'a dart test step extracts pass/fail counts from the summary',
      () async {
        final runner = runnerWith((command, cwd) async {
          final argv = command.join(' ');
          if (argv.startsWith('dart pub get')) return ok('Got dependencies!');
          if (argv.startsWith('dart test')) {
            // A failing dart-test run exits 65 (the SDK contract).
            return ProcessResult(
              3,
              65,
              '00:01 +2: loading\n00:03 +2 -1: Some tests failed.\n',
              '',
            );
          }
          throw StateError('unexpected spawn: $argv');
        });
        final real = DifferentialEntry(
          name: 'e',
          incident: null,
          description: 'd',
          steps: [
            DifferentialStepSpec(argv: ['dart', 'test', 'test/tdd']),
          ],
          artifactRoots: const ['test/tdd'],
          projectDir: scaffold.path,
        );
        final vector = await runner.runEntry(
          entry: real,
          ref: 'HEAD',
          worktreePath: p.join(temp.path, 'wt'),
          scratch: scratch,
        );
        expect(vector.steps.single.outcome, DifferentialStepOutcome.failed);
        expect(vector.steps.single.passCount, 2);
        expect(vector.steps.single.failCount, 1);
      },
    );

    test(
      'a failed scratch pub get is a setup exception naming the scratch',
      () async {
        final runner = runnerWith((command, cwd) async {
          if (command.join(' ').startsWith('dart pub get') &&
              p.basename(cwd) == 'project') {
            return fail('', 'no solution');
          }
          return ok('');
        });
        final real = DifferentialEntry(
          name: 'e',
          incident: null,
          description: 'd',
          steps: [
            DifferentialStepSpec(argv: ['tdd', 'gen', 'U1']),
          ],
          artifactRoots: const ['test/tdd'],
          projectDir: scaffold.path,
        );
        await expectLater(
          () => runner.runEntry(
            entry: real,
            ref: 'HEAD',
            worktreePath: p.join(temp.path, 'wt'),
            scratch: scratch,
          ),
          throwsA(isA<DifferentialSetupException>()),
        );
      },
    );
  });

  group('extraction helpers', () {
    test('extractMachineToken prefers the gen JSON verdict line', () {
      final out =
          'behavior_id: U1\n'
          '{"behaviorId":"U1","verdict":"created","created":["x"]}\n';
      expect(DifferentialRefRunner.extractMachineToken(out), 'created');
    });

    test('extractMachineToken falls back to the make summary line', () {
      expect(
        DifferentialRefRunner.extractMachineToken(
          'make: behavior=U1 outcome=red feature=f\n',
        ),
        'red',
      );
    });

    test('extractMachineToken falls back to the result= contract', () {
      expect(
        DifferentialRefRunner.extractMachineToken(
          'run: feature=f result=complete\n',
        ),
        'complete',
      );
    });

    test('extractMachineToken returns null when no contract spoke', () {
      expect(
        DifferentialRefRunner.extractMachineToken('nothing here\n'),
        isNull,
      );
    });

    test('parseTestCounts reads the final dart-test counters line', () {
      expect(
        DifferentialRefRunner.parseTestCounts(
          '00:03 +2 -1: Some tests failed.',
        ),
        isNotNull,
      );
      final c = DifferentialRefRunner.parseTestCounts(
        '00:03 +2 -1: Some tests failed.',
      )!;
      expect(c.$1, 2);
      expect(c.$2, 1);
      final all = DifferentialRefRunner.parseTestCounts(
        '00:03 +10: All tests passed!',
      )!;
      expect(all.$1, 10);
      expect(all.$2, 0);
      expect(DifferentialRefRunner.parseTestCounts('no counters'), isNull);
    });
  });

  group('json shape', () {
    test('StepVector round-trips through to/fromJson for report payloads', () {
      const s = StepVector(
        label: 'gen U2',
        exitCode: -1,
        outcome: DifferentialStepOutcome.hang,
        token: null,
        passCount: null,
        failCount: null,
      );
      final back = StepVector.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(back, equals(s));
    });
  });
}
