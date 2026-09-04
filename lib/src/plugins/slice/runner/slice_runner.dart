/// SliceRunner (spec 043): flutter run wrapper (FR-016).
///
/// Thin wrapper (research R-010): resolve the slice manifest, fast-verify
/// the slice, then execute `flutter run -t <main_slice.dart>` from the
/// PROJECT ROOT (where pubspec.yaml, .dart_tool/, and build/ live),
/// forwarding any extra flags verbatim.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../capabilities/cut_slice_capability.dart';
import '../verifier/import_verifier.dart';

/// Process execution seam (injected in tests; defaults to [Process.run]).
typedef RunLauncher =
    Future<ProcessResult> Function(
      String executable,
      List<String> args, {
      String? workingDirectory,
    });

/// The outcome of a launch attempt.
class RunResult {
  /// Creates the result.
  const RunResult({required this.launched, this.message, this.exitCode = 0});

  /// Whether `flutter run` was actually executed.
  final bool launched;

  /// Human-readable summary (verification failures, launch errors).
  final String? message;

  /// The exit code of the launched process (0 when not launched).
  final int exitCode;
}

/// Launches a slice via `flutter run -t <main_slice.dart>` from the
/// project root, after fast-mode verification.
class SliceRunner {
  /// Creates the runner with injectable collaborators.
  SliceRunner({RunLauncher? launcher, ImportVerifier? importVerifier})
    : _launcher = launcher ?? _defaultLauncher,
      _importVerifier = importVerifier ?? ImportVerifier();

  final RunLauncher _launcher;
  final ImportVerifier _importVerifier;

  static Future<ProcessResult> _defaultLauncher(
    String executable,
    List<String> args, {
    String? workingDirectory,
  }) {
    return Process.run(executable, args, workingDirectory: workingDirectory);
  }

  /// Runs the slice [sliceName] cut from [projectRoot], forwarding
  /// [extraArgs] to `flutter run` verbatim.
  Future<RunResult> runSlice({
    required String sliceName,
    required String projectRoot,
    required List<String> extraArgs,
  }) async {
    final sandboxDir = CutSliceCapability.sandboxDirFor(projectRoot, sliceName);
    if (!Directory(sandboxDir).existsSync()) {
      return RunResult(
        launched: false,
        message:
            'No slice named "$sliceName" found at '
            '${p.relative(sandboxDir, from: projectRoot)}. Run `zfa slice '
            'cut $sliceName --entry <point>` first.',
      );
    }

    // Verify first (A21): a broken slice must abort before launch.
    final report = _importVerifier.verify(
      sandboxDir: sandboxDir,
      projectRoot: projectRoot,
    );
    if (!report.passed) {
      return RunResult(
        launched: false,
        message:
            '${report.issues.length} unresolved import(s) — the slice is '
            'incomplete. Fix the slice (or re-cut it) before running:\n'
            '${report.issues.take(5).map((i) => '  $i').join('\n')}',
      );
    }

    final entryPoint = p.join(sandboxDir, 'main_slice.dart');
    final args = ['run', '-t', entryPoint, ...extraArgs];
    final result = await _launcher(
      'flutter',
      args,
      workingDirectory: projectRoot,
    );
    return RunResult(
      launched: true,
      exitCode: result.exitCode,
      message: 'flutter run exited with code ${result.exitCode}.',
    );
  }
}
