import 'dart:io';
import 'package:args/command_runner.dart';

/// Base class for all Zuraffa CLI commands.
///
/// Provides standardized behavior:
/// - `exitOnCompletion` control for MCP/embedded use
/// - Automatic rest argument handling
/// - Consistent error handling
abstract class StandardCommand extends Command<void> {
  /// Whether to call exit() after command completion.
  /// Set to false for MCP server and testing.
  final bool exitOnCompletion;

  StandardCommand({this.exitOnCompletion = true});

  /// Arguments passed after the command name.
  List<String> get restArgs => argResults?.rest ?? [];

  /// Exit with code if exitOnCompletion is true.
  void exitIfEnabled(int code) {
    if (exitOnCompletion) {
      exit(code);
    }
  }

  /// Print error and optionally exit.
  void error(String message, {int code = 1}) {
    print('❌ $message');
    exitIfEnabled(code);
  }

  /// Print success message.
  void success(String message) {
    print('✅ $message');
  }
}
