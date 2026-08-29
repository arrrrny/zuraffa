/// `zfa tdd verify` — runs the `mutation_test` audit on the configured TDD
/// code scope and writes the score to the feature's `tdd/verification.md`.
///
/// Phase 11 of `specs/041-tdd-setup-plugin/tasks.md` (tasks T077–T081)
/// required this command. Before this implementation, the command was an
/// honest misfire-stop stub (it threw `StateError` naming T077–T081). That
/// was load-bearing: it prevented fake-pass PR merges while the underlying
/// `mutation_test` wiring was still pending.
///
/// Now that the wiring exists (`mutation-test.xml` at the repo root, plus
/// the `MutationVerifier` service), this command:
///   1. Invokes `dart run mutation_test mutation-test.xml -f md -o
///      mutation-test-report` via [MutationVerifier].
///   2. Prints the score to stdout in a machine-readable line:
///      `mutation: killed=X survived=Y timeout=Z score=0.9N`.
///   3. Optionally appends the score to the feature's
///      `tdd/verification.md` when `--feature <name>` is passed.
///   4. Exits non-zero when survivors exist (per US9.AC3 of the spec,
///      "the audit must fail when survivors exceed the rubric's tolerance").
library;

import 'dart:io';

import 'package:args/command_runner.dart';

import '../services/mutation_verifier.dart';
import '../tdd_plugin.dart';

class VerifyCommand extends Command<void> {
  VerifyCommand(this.plugin) {
    argParser.addOption(
      'feature',
      help: 'Feature name (e.g. 041-tdd-setup-plugin). When set, the audit '
          'score is appended to specs/<feature>/tdd/verification.md.',
    );
  }

  final TddPlugin plugin;

  @override
  String get name => 'verify';

  @override
  String get description =>
      'Run the mutation_test audit on the TDD code scope and write the '
      'score to tdd/verification.md. See specs/041-tdd-setup-plugin (US9).';

  @override
  String get invocation => 'zfa tdd verify [--feature <name>]';

  @override
  Future<void> run() async {
    final argResults = this.argResults;
    final feature = argResults?['feature'] as String?;
    final cwd = Directory.current.path;

    final verifier = MutationVerifier(workingDirectory: cwd);
    stdout.writeln('zfa tdd verify: running mutation_test...');
    stdout.writeln('   config: ${verifier.configPath}');
    stdout.writeln('   output: ${verifier.outputDir}/');

    final MutationResult result;
    try {
      result = await verifier.run();
    } on MutationToolUnavailable catch (e) {
      stderr.writeln('zfa tdd verify: $e');
      throw StateError('zfa tdd verify: mutation tool unavailable');
    } on MutationConfigError catch (e) {
      stderr.writeln('zfa tdd verify: $e');
      throw StateError('zfa tdd verify: config error');
    }

    stdout.writeln(
      '   killed:  ${result.killedCount}',
    );
    stdout.writeln(
      '   survived: ${result.survivedCount}',
    );
    stdout.writeln(
      '   timeout: ${result.timeoutCount}',
    );
    stdout.writeln(
      '   score:   ${(result.score * 100).toStringAsFixed(1)}% '
      '(${result.killedCount}/${result.totalMutants})',
    );
    stdout.writeln(
      '   elapsed: ${result.elapsed.inSeconds}s',
    );
    if (result.reportPath != null) {
      stdout.writeln('   report:  ${result.reportPath}');
    }

    // Machine-readable summary line for CI / scripts.
    stdout.writeln(
      'mutation: killed=${result.killedCount} '
      'survived=${result.survivedCount} '
      'timeout=${result.timeoutCount} '
      'score=${result.score.toStringAsFixed(4)}',
    );

    if (feature != null && feature.isNotEmpty) {
      await _appendVerification(feature, result, cwd);
    }

    if (!result.passed) {
      // Per US9.AC3: exit non-zero when survivors exist.
      throw UsageException(
        'mutation audit failed: ${result.survivedCount} mutant(s) '
        'survived the test suite.',
        'Run with --feature <name> to append the score to the spec '
        'verification, then strengthen the tests in test/plugins/tdd/ '
        'until score=1.0.',
      );
    }
  }
}

/// Appends a one-line audit record to
/// `specs/<feature>/tdd/verification.md`. This is the durable artifact
/// reviewers look at when grading TDD discipline.
Future<void> _appendVerification(
  String feature,
  MutationResult result,
  String repoRoot,
) async {
  final dir = Directory('$repoRoot/specs/$feature/tdd');
  final file = File('${dir.path}/verification.md');
  await dir.create(recursive: true);

  final ts = DateTime.now().toUtc().toIso8601String();
  final line = '\n## Mutation audit — $ts\n'
      '- killed: ${result.killedCount}\n'
      '- survived: ${result.survivedCount}\n'
      '- timeout: ${result.timeoutCount}\n'
      '- total: ${result.totalMutants}\n'
      '- score: ${(result.score * 100).toStringAsFixed(1)}% '
      '(${result.killedCount}*${result.totalMutants})\n'
      '- elapsed: ${result.elapsed.inSeconds}s\n'
      '- report: ${result.reportPath ?? "(no report file)"}\n'
      '- exit_code: ${result.exitCode}\n'
      "- tool: `dart run mutation_test mutation-test.xml`\n";

  final exists = await file.exists();
  if (!exists) {
    await file.writeAsString(
      '# TDD Verification — feature $feature\n\n'
      'Append-only audit log. Newest entry last.\n',
    );
  }
  final sink = file.openWrite(mode: FileMode.append);
  sink.write(line);
  await sink.close();
}
