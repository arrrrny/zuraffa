/// Issue #1265 — generators must declare the imports they emit.
///
/// Before this module, the toolchain was inconsistent about generated code
/// importing packages the target pubspec does not declare:
///
/// - `zfa make` detected the gap (issue #1190's
///   `GeneratedImportScanner`) but only WARNED — the tree it left behind
///   compiled solely through a transitive dependency;
/// - `zfa app shell` emitted `package:go_router` imports with no check at
///   all — its router builder hard-requires go_router, yet a stock
///   consumer project (`zfa tdd init` + `zfa app shell`) did not compile
///   unless the author happened to add the dependency.
///
/// This module is the shared remediation both generators (and any future
/// one) route their gap through:
///
/// - [PubspecAutoAdd] performs the mechanical auto-add: ONE
///   `<flutter|dart> pub add <packages…>` invocation in the target root —
///   the same convention the `zfa doctor generated-imports --fix` path
///   (issue #1190) already established. Process spawning is injectable so
///   tests stay hermetic; a failed/absent process (offline, resolution
///   conflict, missing Flutter SDK) degrades honestly instead of crashing.
/// - [PubspecGapReporter] renders the completion diagnostics:
///   the success line naming what was declared, and — when the add is
///   impossible — the SAME `⚠️ pubspec.yaml doesn't declare … --> fix:`
///   diagnostic `zfa make` has printed since #1190, so every generator
///   speaks with one voice.
library;

import 'dart:io';

/// Signature for the process spawner used by the mechanical auto-add.
/// Injectable so tests can record invocations without side effects
/// (mirrors the `ZfaProcessRunner` typedef in doctor_checks.dart).
typedef PubspecProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> args);

/// Outcome of one [PubspecAutoAdd.add] attempt.
class PubspecAutoAddResult {
  const PubspecAutoAddResult({
    required this.requested,
    required this.added,
    required this.failed,
    this.commandLine,
  });

  /// Packages the caller asked to declare (sorted, deduplicated).
  final List<String> requested;

  /// Packages whose `pub add` succeeded (the whole request at once —
  /// `pub add` is transactional per invocation, so this is either all of
  /// [requested] or empty).
  final List<String> added;

  /// Packages whose `pub add` did not succeed (non-zero exit, missing
  /// executable, …). Callers must surface the gap diagnostic for these.
  final List<String> failed;

  /// The exact command the auto-add ran (or would run), e.g.
  /// `flutter pub add go_router` — null when nothing was attempted.
  final String? commandLine;

  /// True when there was nothing to do (no hosted gap packages).
  bool get isNoOp => requested.isEmpty;
}

/// Adds the packages generated code imports to the target pubspec.yaml via
/// one `pub add` invocation. Offline-safe at the call site: failures are
/// reported in [PubspecAutoAddResult.failed], never thrown.
class PubspecAutoAdd {
  /// Fallback spawner with the same generous timeout convention as the
  /// doctor fixes (`Process.run` under a network-resolving `pub add`).
  static Future<ProcessResult> _defaultProcessRunner(
    String executable,
    List<String> args,
  ) async {
    return Process.run(executable, args).timeout(const Duration(minutes: 10));
  }

  /// Runs `<flutter|dart> pub add <packages…>` in [projectRoot].
  ///
  /// [isFlutter] selects `flutter pub add` — the standalone `dart`
  /// executable cannot resolve `sdk: flutter` graphs (the same convention
  /// `DependencyWirer.wire` applies). Pass [runner] in tests to record the
  /// invocation hermetically; when [dryRun] is true nothing is spawned and
  /// a no-op result is returned.
  static Future<PubspecAutoAddResult> add({
    required String projectRoot,
    required Iterable<String> packages,
    required bool isFlutter,
    bool dryRun = false,
    PubspecProcessRunner? runner,
  }) {
    return addWith(
      projectRoot: projectRoot,
      packages: packages,
      isFlutter: isFlutter,
      dryRun: dryRun,
      runner: runner ?? _defaultProcessRunner,
    );
  }

  /// Same as [add] with the spawner required — the seam the injectable
  /// tests drive directly.
  static Future<PubspecAutoAddResult> addWith({
    required String projectRoot,
    required Iterable<String> packages,
    required bool isFlutter,
    bool dryRun = false,
    required PubspecProcessRunner runner,
  }) async {
    final requested = packages.toSet().toList()..sort();
    if (requested.isEmpty || dryRun) {
      return const PubspecAutoAddResult(requested: [], added: [], failed: []);
    }

    final executable = isFlutter ? 'flutter' : 'dart';
    final args = ['pub', 'add', ...requested];
    final commandLine = '$executable ${args.join(' ')}';

    try {
      final result = await runner(executable, args);
      if (result.exitCode == 0) {
        return PubspecAutoAddResult(
          requested: requested,
          added: requested,
          failed: const [],
          commandLine: commandLine,
        );
      }
    } catch (_) {
      // Missing executable / spawn failure — degrade to the diagnostic.
    }
    return PubspecAutoAddResult(
      requested: requested,
      added: const [],
      failed: requested,
      commandLine: commandLine,
    );
  }
}

/// The unified completion diagnostics for the generated-imports ↔ pubspec
/// gap. Both `zfa make` and `zfa app shell` print THESE lines (via
/// [PubspecGapReporter]) so the wording can never drift between
/// generators.
class PubspecGapReporter {
  /// Lines printed when the auto-add succeeded: what was declared and the
  /// exact command that declared it.
  static List<String> successLines({
    required List<String> added,
    required String commandLine,
  }) {
    return [
      '✅ Auto-added ${added.length} pubspec.yaml dependency(ies) for '
          'generated imports: ${added.join(", ")}',
      '    ran: `$commandLine`',
    ];
  }

  /// Lines printed when the gap could not be healed mechanically — the
  /// make-consistent `⚠️ doesn't declare … --> fix:` diagnostic (#1190
  /// wording, verbatim). SDK-provided packages (flutter, flutter_test, …)
  /// cannot be `pub add`ed and get their own note instead.
  static List<String> gapWarningLines({
    required List<String> missing,
    String? pubAddOneLiner,
    List<String> sdkMissingPackages = const [],
  }) {
    if (missing.isEmpty && sdkMissingPackages.isEmpty) return const [];
    final lines = <String>[
      '⚠️  pubspec.yaml doesn\'t declare ${missing.length} '
          'package(s) the generated code imports: ${missing.join(", ")}',
    ];
    if (pubAddOneLiner != null) {
      lines.add('    --> fix: `$pubAddOneLiner`');
    }
    if (sdkMissingPackages.isNotEmpty) {
      lines.add(
        '    note: ${sdkMissingPackages.join(", ")} come(s) from the '
        'Flutter SDK — declare with `sdk: flutter` in pubspec.yaml',
      );
    }
    lines.add('    note: re-check the whole tree with `zfa doctor`');
    return lines;
  }
}
