/// `FormatRunner` — the pub-get-enforcing, scope-limited path to
/// `dart format` for CLI commands (issue #1506).
///
/// A fresh clone has no `.dart_tool/package_config.json`. When `dart
/// format` then reads `analysis_options.yaml`, its
/// `include: package:lints/recommended.yaml` cannot be resolved and the
/// formatter emits a `Package resolution error` warning for EVERY
/// formatted file — and, falling back to default formatting rules,
/// rewrites hundreds of unrelated files (868 files in the #1506
/// reproduction on Dart 3.13.2).
///
/// This runner makes that state unreachable through the CLI:
///
///   1. An empty scope is a no-op — no process is ever spawned.
///   2. A tree-wide scope (`.` / `./`) throws `ArgumentError` BEFORE any
///      process runs: whole-tree formatting as a side effect of a
///      generation command is the blast-radius class under fix.
///   3. Without package resolution, `dart pub get --no-example` runs
///      FIRST (the same order CI enforces). If it fails, the formatter
///      is never spawned and exactly ONE actionable warning is returned
///      — the per-file warning spam cannot occur.
///   4. With resolution present (or established), `dart format` runs
///      against exactly the caller-provided paths — the intended files,
///      never an implicit tree.
///
/// The process runner is injectable (the `PubspecProcessRunner` typedef
/// convention, `pubspec_auto_add.dart`) so tests stay hermetic.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Injectable process runner for [FormatRunner] — the
/// [PubspecProcessRunner] typedef shape (`pubspec_auto_add.dart`), so
/// the recording-runner test conventions apply unchanged.
typedef FormatProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> args,
      String workingDirectory,
    );

/// The outcome of one [FormatRunner.formatPaths] attempt.
class FormatRunResult {
  const FormatRunResult({
    required this.formatRan,
    required this.pubGetRan,
    required this.skipped,
    required this.exitCode,
    this.warning,
  });

  /// True when `dart format` was actually invoked with the scoped paths.
  final bool formatRan;

  /// True when the pub-get enforcement ran (resolution was missing).
  final bool pubGetRan;

  /// True when the formatter was intentionally NOT invoked (empty scope
  /// or unresolvable packages).
  final bool skipped;

  /// The `dart format` exit code; `-1` when the formatter never ran.
  final int exitCode;

  /// The single actionable warning when formatting was skipped due to
  /// unresolvable packages; null otherwise. Never a per-file spam — the
  /// runner emits at most this one warning.
  final String? warning;
}

/// The single CLI path to `dart format` — see the library docs.
class FormatRunner {
  FormatRunner({FormatProcessRunner? processRunner})
    : _processRunner = processRunner ?? _defaultProcessRunner;

  final FormatProcessRunner _processRunner;

  /// Format exactly [paths] under [workingDirectory] (issue #1506):
  ///
  /// - empty [paths] → skipped, nothing spawned;
  /// - a whole-tree scope (`.` / `./`) → `ArgumentError` before any
  ///   process;
  /// - missing `.dart_tool/package_config.json` →
  ///   `dart pub get --no-example` first (FR-1); when that fails the
  ///   formatter is skipped with one warning (the `dart format`
  ///   without resolution is the #1506 warning-spam + tree-rewrite
  ///   state and is unreachable here);
  /// - otherwise → `dart format <paths...>` verbatim.
  Future<FormatRunResult> formatPaths(
    List<String> paths, {
    String workingDirectory = '.',
  }) async {
    final scope = paths
        .where((path) => path.trim().isNotEmpty)
        .toList(growable: false);
    if (scope.isEmpty) {
      return const FormatRunResult(
        formatRan: false,
        pubGetRan: false,
        skipped: true,
        exitCode: -1,
      );
    }
    _guardAgainstTreeWideScope(scope);

    final resolution = await _ensurePackageResolved(workingDirectory);
    if (!resolution.established) {
      return FormatRunResult(
        formatRan: false,
        pubGetRan: resolution.ranPubGet,
        skipped: true,
        exitCode: -1,
        warning: _unresolvedWarning,
      );
    }

    final result = await _processRunner('dart', [
      'format',
      ...scope,
    ], workingDirectory);
    return FormatRunResult(
      formatRan: true,
      pubGetRan: resolution.ranPubGet,
      skipped: false,
      exitCode: result.exitCode,
    );
  }

  /// FR-2: a whole-tree scope is the blast-radius amplifier from #1506
  /// (the formatter rewrites every file under the working directory).
  /// Rejected BEFORE any process is spawned — a warning could be
  /// scrolled past; the guard cannot.
  void _guardAgainstTreeWideScope(List<String> scope) {
    for (final path in scope) {
      final normalized = p.normalize(path);
      if (normalized == '.' || normalized == p.current) {
        throw ArgumentError.value(
          path,
          'paths',
          'refusing to format the whole tree (issue #1506): pass the '
              'intended files or the generated output directory instead',
        );
      }
    }
  }

  /// FR-1: verify package resolution, enforcing `dart pub get
  /// --no-example` when missing. `established` is false only when
  /// resolution cannot be verified — the caller must then NOT spawn the
  /// formatter. `ranPubGet` reports whether the enforcement fired.
  Future<({bool established, bool ranPubGet})> _ensurePackageResolved(
    String workingDirectory,
  ) async {
    final packageConfig = File(
      p.join(workingDirectory, '.dart_tool', 'package_config.json'),
    );
    if (packageConfig.existsSync()) {
      return (established: true, ranPubGet: false);
    }

    final pubGet = await _processRunner('dart', const [
      'pub',
      'get',
      '--no-example',
    ], workingDirectory);
    return (
      established: pubGet.exitCode == 0 && packageConfig.existsSync(),
      ranPubGet: true,
    );
  }

  /// The ONE warning the runner may emit when formatting is skipped —
  /// actionable, and named so a Flutter host (where `dart pub get`
  /// cannot resolve flutter_test SDK pins) knows the working alternative.
  static const String _unresolvedWarning =
      'Skipping dart format: package resolution is unavailable '
      '(.dart_tool/package_config.json missing and `dart pub get '
      '--no-example` failed). Formatting without resolution mis-formats '
      'the tree and spams package-resolution warnings (issue #1506). '
      'Run `dart pub get --no-example` (or `flutter pub get` in a '
      'Flutter project) and re-run.';

  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> args,
    String workingDirectory,
  ) => Process.run(executable, args, workingDirectory: workingDirectory);
}
