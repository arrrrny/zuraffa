import 'dart:async';
import 'cli/cli_runner.dart';

/// Run CLI with arguments - main entry point.
Future<void> run(List<String> args) async {
  final runner = CliRunner(exitOnCompletion: true);
  await runner.run(args);
}

/// Run CLI and capture output - for MCP server embedding.
Future<String> runCapturing(List<String> args) async {
  final runner = CliRunner(exitOnCompletion: false);
  return await runner.runCapturing(args);
}
