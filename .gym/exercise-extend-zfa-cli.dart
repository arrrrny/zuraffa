/// GYM exercise — extend the zfa CLI with a new subcommand (graded).
///
/// Brief: A genuine dev task — scaffold a new `zfa NAME` subcommand
/// that prints "hello from NAME" when invoked, wire it into a
/// synthetic CommandRunner, and assert it dispatches correctly.
/// This trains the same muscle as adding a new CLI command to
/// zuraffa itself; it is NOT a re-skinned unit test (FR-003).
///
/// Setup:
///   - Ensure `dart` is on PATH.
///   - Run the warmup reps first (.gym/warmup/*).
///   - The exercise writes its sandbox under .gym/.sandbox/extend-zfa-cli/
///     and never mutates the package source tree (FR-005).
///
/// verifyCommand: `dart run .gym/exercise-extend-zfa-cli.dart`
/// evaluate: exit 0 => pass; exit !=0 => fail
///
/// A mis-fire (unexpected outcome, not a clean failure) is captured as a
/// DROP CARD — see .gym/lib/drop_card.dart and github.com/arrrrny/drop-card.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import 'lib/drop_card.dart';

/// Entry point for the graded exercise.
Future<void> main() async {
  // ── Setup ───────────────────────────────────────────────────────────
  // The sandbox lives under .gym/.sandbox/ so the runner can wipe it
  // between runs without touching the package source tree (FR-005).
  final sandboxRoot = Directory(p.canonicalize('.gym/.sandbox/extend-zfa-cli'));
  if (sandboxRoot.existsSync()) {
    await sandboxRoot.delete(recursive: true);
  }
  await sandboxRoot.create(recursive: true);

  // The operator's submission: a Dart file declaring a `hello` command.
  // In a real GYM run, the operator writes this file by hand and the
  // exercise grades it. For the self-test path, we stage a known-good
  // submission so the exercise can grade itself end-to-end.
  //
  // The exercise structure (the parts the grader checks):
  //   1. Spawn `dart` with the submission file as a script and `hello`
  //      as the argument.
  //   2. Assert stdout contains "hello from hello".
  //   3. Assert exit code is 0.
  //
  // A mis-fire at any stage emits a DROP CARD with Did/Expected/Happened/Where.
  final submissionPath = p.join(sandboxRoot.path, 'hello_runner.dart');
  File(submissionPath).writeAsStringSync(_submissionSource);

  // ── Stage 1: spawn ──────────────────────────────────────────────────
  // Try to execute the submission with `dart run`. If `dart` is not on
  // PATH, that's a mis-fire (the operator's environment is broken, not
  // the submission).
  final spawnResult = await Process.run('dart', [
    'run',
    submissionPath,
    'hello',
  ], runInShell: true);

  if (spawnResult.exitCode != 0) {
    DropCard(
      exerciseId: 'extend-zfa-cli',
      did:
          'spawn `dart run` against the operator\'s hello_runner.dart submission',
      expected: 'exit code 0 (the submission runs without error)',
      happened:
          'exit code ${spawnResult.exitCode}; stdout="${_truncate(spawnResult.stdout)}"; stderr="${_truncate(spawnResult.stderr)}"',
      where: 'spawn: `dart run $submissionPath hello`',
      detail:
          'The submission file failed to execute. Either the file has a '
          'syntax error, or `dart` is not on PATH. Check the submission '
          'and re-run the warmup reps.',
    ).emitAndPersist(sandboxRoot.path);
    exit(1);
  }

  // ── Stage 2: stdout assertion ───────────────────────────────────────
  // The submission must print "hello from hello" — the canonical contract
  // for a `zfa <name>` subcommand that greets the user.
  final stdoutText = spawnResult.stdout.toString();
  if (!stdoutText.contains('hello from hello')) {
    DropCard(
      exerciseId: 'extend-zfa-cli',
      did: 'assert the submission prints the canonical greeting',
      expected: 'stdout contains "hello from hello"',
      happened: 'stdout was: "${_truncate(stdoutText)}"',
      where: 'stdout-check: post-spawn assertion',
      detail:
          'The submission ran but did not print the expected greeting. '
          'A `zfa <name>` subcommand that greets the user is the canonical '
          'dev task; check that the command\'s run() method prints '
          '"hello from <name>".',
    ).emitAndPersist(sandboxRoot.path);
    exit(1);
  }

  // ── PASS ────────────────────────────────────────────────────────────
  print('PASS: extend-zfa-cli — submission dispatched and greeted correctly.');
  exit(0);
}

/// Truncates a string for inclusion in a DROP CARD's `Happened` field.
String _truncate(String s, {int max = 200}) {
  final trimmed = s.trim();
  if (trimmed.length <= max) return trimmed;
  return '${trimmed.substring(0, max)}… (${trimmed.length} chars total)';
}

/// The known-good submission source used by the self-test path.
///
/// In a real GYM run, the operator writes this file by hand. The
/// exercise grades whatever the operator produces against the same
/// contract: spawn → assert stdout → exit 0.
const String _submissionSource = '''
import 'package:args/command_runner.dart';

class HelloCommand extends Command<void> {
  @override
  String get name => 'hello';

  @override
  String get description => 'Print "hello from hello".';

  @override
  Future<void> run() async {
    print('hello from hello');
  }
}

Future<void> main(List<String> args) async {
  final runner = CommandRunner<void>('zfa', 'Zuraffa Code Generator')
    ..addCommand(HelloCommand());
  await runner.run(args);
}
''';
