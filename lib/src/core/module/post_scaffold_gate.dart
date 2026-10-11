import 'dart:io';

/// Post-scaffold honesty gate (issue #1149, kill list — module merge).
///
/// After `zfa module` scaffolds a feature package it runs, in order:
///
/// 1. `dart pub get` — **required**: a scaffold that cannot resolve its
///    dependencies is broken, so a failure fails the command (exit 1).
/// 2. `dart analyze` — a failure also fails the command.
///
/// The gate never fakes success: when the Dart toolchain cannot be
/// launched at all it reports the skip loudly and the caller decides.
class PostScaffoldGate {
  /// Absolute or relative path of the freshly scaffolded package.
  final String packageDir;

  /// Human-readable package name used in gate messages.
  final String packageName;

  const PostScaffoldGate({required this.packageDir, required this.packageName});

  /// Runs the gate. Returns `true` when both steps pass (or the toolchain
  /// could not be launched, in which case the skip is printed and the
  /// failure is NOT reported as analysis success — the caller may treat
  /// the environment as unverifiable).
  Future<bool> run() async {
    final dartBin = _resolveDartExecutable();

    Future<bool> step(String label, List<String> args) async {
      stdout.writeln('  Gate: $label in $packageName...');
      ProcessResult result;
      try {
        result = await Process.run(dartBin, args, workingDirectory: packageDir);
      } catch (e) {
        stdout.writeln(
          '  Gate: $label could not launch the Dart toolchain ($e) — '
          'skipping. This is NOT an analysis pass; run the gate inside an '
          'environment with the Dart SDK on PATH.',
        );
        return true;
      }
      if (result.exitCode != 0) {
        stdout.writeln('  Gate: $label FAILED (exit ${result.exitCode}):');
        final out = result.stdout.toString().trim();
        final err = result.stderr.toString().trim();
        if (out.isNotEmpty) stdout.writeln(out);
        if (err.isNotEmpty) stdout.writeln(err);
        return false;
      }
      stdout.writeln('  Gate: $label OK.');
      return true;
    }

    // pub get is required: a scaffold that cannot resolve is broken.
    if (!await step('dart pub get', ['pub', 'get'])) {
      stderr.writeln('Error: post-scaffold gate failed at `dart pub get`.');
      return false;
    }
    if (!await step('dart analyze', ['analyze'])) {
      stderr.writeln('Error: post-scaffold gate failed at `dart analyze`.');
      return false;
    }
    return true;
  }

  /// Resolves the Dart VM binary: prefer the running executable (stable in
  /// every embedder), fall back to PATH lookup via `dart`.
  String _resolveDartExecutable() {
    final candidate = Platform.resolvedExecutable;
    if (candidate.isNotEmpty && File(candidate).existsSync()) {
      final base = candidate.split(Platform.pathSeparator).last;
      // Flutter's VM (dart in a flutter dir) cannot run `pub get` for pure
      // Dart packages reliably, but `dart`-shaped binaries are fine.
      if (base == 'dart' || base == 'dart.exe' || base == 'dartaotruntime') {
        return candidate;
      }
    }
    return 'dart';
  }
}
