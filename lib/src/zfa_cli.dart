import 'dart:async';
import 'dart:io';

import 'cli/cli_runner.dart';
import 'cli/exit_protocol.dart';
import 'core/uncaught_error_funnel.dart';

/// Run CLI with arguments - main entry point.
Future<void> run(List<String> args) async {
  final runner = CliRunner(exitOnCompletion: true);
  await runner.run(args);
}

/// The `Zuraffa.runGuarded` handler the CLI entrypoints (`bin/zfa.dart`,
/// `bin/zuraffa.dart`) install.
///
/// An error reaching here never reached the command dispatcher — the runner
/// catches every error it handles and exits through [ExitProtocol] — so no
/// command exit code was ever chosen. The funnel still sees it (SEVERE record,
/// optional failure span), and then the CLI ends the way it did before the
/// funnel: the error and its stack trace on stderr, and a nonzero status.
///
/// Without this handler the funnel's default only LOGS: nothing listens on
/// `Logger.root` in the CLI, so `zfa -C /nonexistent` printed nothing and
/// exited **0** — a hard failure reported as success.
void reportUncaughtCliError(Object error, StackTrace stackTrace) {
  UncaughtErrorFunnel.captureUncaught(error, stackTrace);
  stderr.writeln('❌ Error: $error');
  stderr.writeln(stackTrace);
  stderr.writeln(
    ExitProtocol.fixLine(
      'this error escaped before a command could report it — run '
      '`zfa doctor` to check the installation',
    ),
  );
  exitCode = ExitProtocol.failure;
}

/// Run CLI and capture output - for MCP server embedding.
Future<String> runCapturing(List<String> args) async {
  final runner = CliRunner(exitOnCompletion: false);
  return await runner.runCapturing(args);
}
