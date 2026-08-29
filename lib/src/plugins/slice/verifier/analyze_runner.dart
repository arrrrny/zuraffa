/// AnalyzeRunner (spec 043): dart/flutter analyze wrapper (FR-014).
///
/// Analyze-mode verification (research R-009): runs `dart analyze` (or
/// `flutter analyze` for Flutter projects) on the sandbox and captures the
/// error lines as a structured result. Process execution goes through an
/// injectable seam so tests stay deterministic and no real toolchain is
/// required.
library;

import 'dart:io';

/// Process execution seam (injected in tests; defaults to [Process.run]).
typedef ProcessLauncher = Future<ProcessResult> Function(
  String executable,
  List<String> args, {
  String? workingDirectory,
});

/// The analyze outcome.
class AnalyzeResult {
  /// Creates the result.
  const AnalyzeResult({
    required this.passed,
    required this.errors,
    this.toolchainMissing = false,
    this.message,
  });

  /// True when the analyzer reported no issues.
  final bool passed;

  /// The analyzer's error lines.
  final List<String> errors;

  /// True when the dart/flutter executable could not be run at all.
  final bool toolchainMissing;

  /// Human-readable summary (environment errors, tool failures).
  final String? message;
}

/// Runs `dart analyze` (or `flutter analyze`) on a sandbox directory.
class AnalyzeRunner {
  /// Creates the runner with an optional [launcher] seam.
  AnalyzeRunner({ProcessLauncher? launcher})
    : _launcher = launcher ?? _defaultLauncher;

  final ProcessLauncher _launcher;

  static Future<ProcessResult> _defaultLauncher(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) {
    return Process.run(executable, args, workingDirectory: workingDirectory);
  }

  /// Analyzes [dir]; [flutter] switches to `flutter analyze`.
  Future<AnalyzeResult> analyze(String dir, {bool flutter = false}) async {
    final executable = flutter ? 'flutter' : 'dart';
    final ProcessResult result;
    try {
      result = await _launcher(
        executable,
        ['analyze', dir],
        workingDirectory: dir,
      );
    } on ProcessException catch (e) {
      return AnalyzeResult(
        passed: false,
        errors: const [],
        toolchainMissing: true,
        message:
            'The `$executable` executable was not found on PATH — install '
            'the ${flutter ? 'Flutter' : 'Dart'} SDK to use --analyze '
            '(${e.message}).',
      );
    }

    final output = (result.stdout as String) + (result.stderr as String);
    if (result.exitCode == 0) {
      return AnalyzeResult(passed: true, errors: const []);
    }

    final errors = output
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.startsWith('error -'))
        .toList();
    return AnalyzeResult(
      passed: false,
      errors: errors,
      message: errors.isEmpty
          ? 'The analyzer exited with code ${result.exitCode}.'
          : null,
    );
  }
}
