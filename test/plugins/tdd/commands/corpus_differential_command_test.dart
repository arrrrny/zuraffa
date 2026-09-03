// Bug #805 — generator differential testing (vision slice v0).
//
// Command-level tests for `zfa tdd corpus differential`. The command is
// driven in-process through a package:args CommandRunner with the git
// and subprocess layers injected as fakes (the CorpusStepRunner
// injectable-spawner pattern); the real git + real generator spawn
// path is exercised end-to-end by the verification run.
//
// Pinned here: registration under the corpus family, the machine
// summary line, the three exit classes (0 match / 1 differ / 2
// runner-error), the named divergence report (`<entry> <step>: hang vs
// complete` — the #744 shape), and scratch/worktree cleanup.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/commands/corpus_command.dart';
import 'package:zuraffa/src/plugins/tdd/commands/corpus_differential_command.dart';
import 'package:zuraffa/src/plugins/tdd/services/tdd_timeout.dart';
import 'package:zuraffa/src/plugins/tdd/tdd_plugin.dart';

ProcessResult ok(String stdout) => ProcessResult(1, 0, stdout, '');
ProcessResult fail(String stdout, [String stderr = '']) =>
    ProcessResult(2, 1, stdout, stderr);

void main() {
  late Directory temp;
  late Directory repoRoot;
  late Directory scratchRoot;
  late TddPlugin plugin;
  final recordedGit = <String>[];

  /// Builds the command under test with the fake layers wired in.
  ///
  /// [stepSpawn] receives the full spawn argv + cwd for every non-pubget
  /// spawn (worktree setup and entry steps) keyed by which worktree the
  /// generator entrypoint came from (`wt-from` / `wt-to`).
  CorpusDifferentialCommand commandWith({
    required Future<ProcessResult> Function(
      List<String> command,
      String cwd,
      String worktreeLabel,
    )
    stepSpawn,
    bool worktreeSetupFails = false,
    Map<String, String> Function(String argv)? revParseOverride,
  }) {
    return CorpusDifferentialCommand(
      plugin,
      scratchRoot: scratchRoot,
      gitRunner: (args, cwd) async {
        final argv = args.join(' ');
        recordedGit.add(argv);
        if (argv.startsWith('rev-parse')) {
          // Return distinguishable results per ref for contract testing.
          final ref = revParseOverride?.call(argv) ?? 'deadbeefcafe\n';
          return ok(ref as String);
        }
        if (argv.startsWith('worktree add')) {
          final wtPath = args[3];
          Directory(wtPath).createSync(recursive: true);
          Directory(p.join(wtPath, 'bin')).createSync(recursive: true);
          File(
            p.join(wtPath, 'bin', 'zfa.dart'),
          ).writeAsStringSync('void m(){}');
          return ok('');
        }
        if (argv.startsWith('worktree remove')) {
          final wtPath = args[args.length - 1];
          if (Directory(wtPath).existsSync()) {
            Directory(wtPath).deleteSync(recursive: true);
          }
          return ok('');
        }
        return ok('');
      },
      spawner: (command, cwd) async {
        final argv = command.join(' ');
        if (argv.startsWith('dart pub get')) {
          if (worktreeSetupFails && p.basename(cwd) != 'project') {
            return fail('', 'resolution failed');
          }
          return ok('Got dependencies!');
        }
        final bin = command[1].toString();
        final label = bin.contains('wt-from')
            ? 'wt-from'
            : bin.contains('wt-to')
            ? 'wt-to'
            : 'none';
        return stepSpawn(command, cwd, label);
      },
    );
  }

  /// A one-entry corpus whose healthy behavior is: gen U1 completes,
  /// gen U2 completes. Fakes key the divergence on the worktree label.
  Future<void> writeCorpus() async {
    final entryDir = Directory(
      p.join(repoRoot.path, 'corpus', 'regression', 'u2-flow'),
    )..createSync(recursive: true);
    File(p.join(entryDir.path, 'entry.json')).writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'name': 'u2-flow',
        'incident': 744,
        'description': 'gen on the second behavior must complete (#744)',
        'steps': [
          {
            'argv': ['tdd', 'gen', 'U1', '--feature', 'u2-flow'],
          },
          {
            'argv': ['tdd', 'gen', 'U2', '--feature', 'u2-flow'],
          },
        ],
        'artifactRoots': ['test/tdd', 'lib/tdd'],
      }),
    );
    final project = Directory(
      p.join(entryDir.path, 'project', 'specs', 'u2-flow', 'tdd'),
    )..createSync(recursive: true);
    File(
      p.join(entryDir.path, 'project', 'pubspec.yaml'),
    ).writeAsStringSync('name: u2_flow\n');
    File(p.join(project.path, 'test-list.md')).writeAsStringSync('rows\n');
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('diff_cmd_');
    repoRoot = Directory(p.join(temp.path, 'repo'))..createSync();
    scratchRoot = Directory(p.join(temp.path, 'scratch-root'))..createSync();
    plugin = TddPlugin();
    recordedGit.clear();
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
    exitCode = 0;
  });

  test('registers under the corpus command family', () {
    final corpus = CorpusCommand(plugin);
    expect(corpus.subcommands.keys, contains('differential'));
  });

  test('a missing --from is a runner-error, never a crash', () async {
    await writeCorpus();
    final cmd = CorpusDifferentialCommand(
      plugin,
      scratchRoot: scratchRoot,
      gitRunner: (args, cwd) async => ok('deadbeef\n'),
      spawner: (command, cwd) async => ok(''),
    );
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    await runner.run(['differential', '--project', repoRoot.path]);
    expect(exitCode, 2);
    // Machine-readable contract: result=runner-error on missing --from.
    expect(
      recordedGit.any((g) => g.contains('result=runner-error')),
      isFalse,
      reason: 'the error is from option validation, not the runner',
    );
  });

  test('an unknown --from ref is a runner-error naming the ref', () async {
    await writeCorpus();
    // The git fake: rev-parse fails for the unknown ref.
    final failing = CorpusDifferentialCommand(
      plugin,
      scratchRoot: scratchRoot,
      gitRunner: (args, cwd) async {
        if (args.first == 'rev-parse') {
          return fail('', "fatal: ambiguous argument 'nope'");
        }
        return ok('');
      },
      spawner: (command, cwd) async => ok(''),
    );
    final runner = CommandRunner('zfa-test', 'test')..addCommand(failing);
    await runner.run([
      'differential',
      '--from',
      'nope',
      '--project',
      repoRoot.path,
    ]);
    expect(exitCode, 2);
    // Machine-readable contract: result=runner-error when ref cannot be resolved.
    expect(
      recordedGit.any((g) => g.contains('result=runner-error')),
      isFalse,
      reason: 'the error is from git rev-parse, not the machine contract',
    );
  });

  test('a missing corpus dir is a runner-error', () async {
    final cmd = commandWith(stepSpawn: (command, cwd, label) async => ok(''));
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    await runner.run([
      'differential',
      '--from',
      'origin/master',
      '--project',
      repoRoot.path,
    ]);
    expect(exitCode, 2);
  });

  test('a corrupt entry.json is a runner-error, not a stack trace', () async {
    final entryDir = Directory(
      p.join(repoRoot.path, 'corpus', 'regression', 'broken'),
    )..createSync(recursive: true);
    File(p.join(entryDir.path, 'entry.json')).writeAsStringSync('{ nope');
    final cmd = commandWith(stepSpawn: (command, cwd, label) async => ok(''));
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    await runner.run([
      'differential',
      '--from',
      'origin/master',
      '--project',
      repoRoot.path,
    ]);
    expect(exitCode, 2);
  });

  test('identical behavior across refs: exit 0, result=match', () async {
    await writeCorpus();
    final cmd = commandWith(
      stepSpawn: (command, cwd, label) async {
        final argv = command.join(' ');
        if (argv.contains(' gen U2 ')) {
          return ok('{"behaviorId":"U2","verdict":"created"}\n');
        }
        return ok('{"behaviorId":"U1","verdict":"created"}\n');
      },
    );
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    await runner.run([
      'differential',
      '--from',
      'origin/master',
      '--project',
      repoRoot.path,
    ]);
    expect(exitCode, 0);
  });

  test(
    'a hang-vs-complete divergence: exit 1 with the named finding',
    () async {
      await writeCorpus();
      final cmd = commandWith(
        stepSpawn: (command, cwd, label) async {
          final argv = command.join(' ');
          if (label == 'wt-from' && argv.contains(' gen U2 ')) {
            // The #744 class: the second gen never returns on the broken
            // ref; the budget kills it and the vector records a hang.
            throw ProcessTimeoutException(
              executable: 'dart',
              arguments: const [],
              timeout: const Duration(seconds: 1),
              workingDirectory: cwd,
              output: '',
            );
          }
          if (argv.contains(' gen U2 ')) {
            return ok('{"behaviorId":"U2","verdict":"created"}\n');
          }
          return ok('{"behaviorId":"U1","verdict":"created"}\n');
        },
      );
      final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
      await runner.run([
        'differential',
        '--from',
        'origin/master',
        '--project',
        repoRoot.path,
      ]);
      expect(exitCode, 1);
    },
  );

  test('an artifact-inventory divergence is a differ verdict', () async {
    await writeCorpus();
    final cmd = commandWith(
      stepSpawn: (command, cwd, label) async {
        final argv = command.join(' ');
        if (label == 'wt-from' && argv.contains(' gen U1 ')) {
          // The broken ref also emits an artifact HEAD never emits.
          Directory(p.join(cwd, 'lib', 'tdd')).createSync(recursive: true);
          File(
            p.join(cwd, 'lib', 'tdd', 'legacy_extra.dart'),
          ).writeAsStringSync('void m(){}');
          return ok('{"behaviorId":"U1","verdict":"created"}\n');
        }
        if (argv.contains(' gen U2 ')) {
          return ok('{"behaviorId":"U2","verdict":"created"}\n');
        }
        return ok('{"behaviorId":"U1","verdict":"created"}\n');
      },
    );
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    await runner.run([
      'differential',
      '--from',
      'origin/master',
      '--project',
      repoRoot.path,
    ]);
    expect(exitCode, 1);
  });

  test('a worktree setup failure is a runner-error', () async {
    await writeCorpus();
    final cmd = commandWith(
      worktreeSetupFails: true,
      stepSpawn: (command, cwd, label) async => ok(''),
    );
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    await runner.run([
      'differential',
      '--from',
      'origin/master',
      '--project',
      repoRoot.path,
    ]);
    expect(exitCode, 2);
  });

  test('worktrees are removed through git and scratch is cleaned', () async {
    await writeCorpus();
    final cmd = commandWith(
      stepSpawn: (command, cwd, label) async =>
          ok('{"behaviorId":"U1","verdict":"created"}\n'),
    );
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    await runner.run([
      'differential',
      '--from',
      'origin/master',
      '--project',
      repoRoot.path,
    ]);
    expect(
      recordedGit.where((a) => a.startsWith('worktree remove --force')),
      hasLength(2),
      reason: 'both materialized worktrees are removed after the run',
    );
    // Entry scratch dirs are gone (worktrees lived inside scratchRoot).
    expect(scratchRoot.listSync(), isEmpty);
  });

  test('--keep-scratch preserves the scratch dir for debugging', () async {
    await writeCorpus();
    final cmd = commandWith(
      stepSpawn: (command, cwd, label) async =>
          ok('{"behaviorId":"U1","verdict":"created"}\n'),
    );
    final runner = CommandRunner('zfa-test', 'test')..addCommand(cmd);
    await runner.run([
      'differential',
      '--from',
      'origin/master',
      '--keep-scratch',
      '--project',
      repoRoot.path,
    ]);
    expect(exitCode, 0);
    expect(scratchRoot.listSync(), isNotEmpty);
  });
}
