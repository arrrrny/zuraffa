/// `PubPreResolver` — pays the cold dependency-resolution cost at INIT time
/// (issue #1653, Ask 2).
///
/// When `zfa tdd init` (or the #1528 preflight's auto-init) newly injects
/// dependency entries into a project's pubspec, the FIRST analyze-class pass
/// after that injection pays a cold cost — dependency download/resolution
/// plus first analysis over the enlarged package config. On a two-file
/// package whose baseline just gained `mutation_test`'s analyzer-versioned
/// graph that cost measured 8m32s, deferred as a surprise into the first
/// refactor inside a `zfa tdd run`. Even with `mutation_test` now opt-in
/// (the same issue's Ask 1), the testing baseline still injects
/// test/build_runner/json_serializable/coverage — and ANY newly injected
/// entry defers a cold resolution into the first refactor unless init pays
/// it itself.
///
/// This service spawns the project's resolver (`dart pub get --no-example`,
/// or `flutter pub get --no-example` for a Flutter target) under a hard
/// deadline ([TddTimeouts.defaultPipelineStep]) and reports the outcome plus
/// the elapsed wall time, which the caller prints — the cost is paid at
/// init time, loudly and visibly, instead of being deferred.
///
/// Failure semantics (the caller's contract, spec 1653 FR-005):
///   * the resolver RAN and exited non-zero → `ran: true, ok: false` — a
///     real resolution failure is a baseline misfire (fail-closed, the
///     #1528 setup-error philosophy: never drive a loop against a baseline
///     that cannot resolve);
///   * the resolver binary could not be STARTED (no `flutter` on PATH for
///     a Flutter target, spawn error) → `ran: false` with an
///     [PubPreResolveReport.unavailableReason] — nothing was proven broken,
///     the environment may resolve elsewhere, so the caller warns loudly
///     and does NOT misfire;
///   * the child outlived the deadline → killed (bug #742 discipline) and
///     reported as `ran: true, ok: false` with the timeout in the output.
library;

import 'dart:io';

import 'tdd_timeout.dart';

/// The outcome of one pre-resolve attempt.
class PubPreResolveReport {
  const PubPreResolveReport({
    required this.ran,
    required this.ok,
    required this.binary,
    this.args = const [],
    this.elapsed,
    this.exitCode,
    this.output = '',
    this.unavailableReason,
  });

  /// True when the resolver process was actually spawned (even if it then
  /// exited non-zero or timed out). False when the binary could not start.
  final bool ran;

  /// True only when the resolver ran and exited zero.
  final bool ok;

  /// The resolver binary ('dart' or 'flutter'); empty when unavailable.
  final String binary;

  /// The argv handed to the binary (excluding the binary itself).
  final List<String> args;

  /// Wall time of the resolution — the number the caller prints so the
  /// cold cost is visible at init time instead of discovered later.
  final Duration? elapsed;

  /// The resolver's exit code (null on a #742-style timeout).
  final int? exitCode;

  /// Combined stdout+stderr (the misfire diagnostics name it).
  final String output;

  /// Non-null when the resolver could not be STARTED at all — the reason
  /// the caller prints as a loud warning (never a silent skip).
  final String? unavailableReason;

  bool get unavailable => !ran && unavailableReason != null;
}

/// The timed-spawn signature [PubPreResolver] uses — a seam so unit tests
/// inject a fake runner and never spawn a real `pub get`.
typedef PubPreResolveRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> args, {
      String? workingDirectory,
      Map<String, String>? environment,
    });

class PubPreResolver {
  const PubPreResolver({
    this.runProcess = defaultRunProcess,
    this.timeout = TddTimeouts.defaultPipelineStep,
  });

  /// The injectable spawn seam (tests pass a recording fake).
  final PubPreResolveRunner runProcess;

  /// The hard deadline for the resolver child (bug #742 discipline: the
  /// default spawn primitive kills at the deadline).
  final Duration timeout;

  static const String dartBinary = 'dart';
  static const String flutterBinary = 'flutter';

  /// The argv both flavors share. `--no-example` keeps a sibling `example/`
  /// package (potentially a Flutter consumer) out of a pure-Dart target's
  /// resolution — the same convention TddFixture uses for its fixtures.
  static const List<String> pubGetArgs = ['pub', 'get', '--no-example'];

  /// The default [runProcess]: the #742 timed spawn primitive.
  static Future<ProcessResult> defaultRunProcess(
    String executable,
    List<String> args, {
    String? workingDirectory,
    Map<String, String>? environment,
  }) {
    return runTimed(
      executable,
      args,
      workingDirectory: workingDirectory,
      timeout: TddTimeouts.defaultPipelineStep,
      environment: environment,
    );
  }

  /// Resolve [projectRoot]'s dependency graph. [isFlutter] selects the
  /// resolver flavor (`flutter pub get` vs `dart pub get`). [onLine] is
  /// unused by the service itself (the caller owns all printing); it is
  /// accepted so callers can pass one sink uniformly.
  Future<PubPreResolveReport> resolve({
    required String projectRoot,
    required bool isFlutter,
    void Function(String line)? onLine,
  }) async {
    final binary = isFlutter ? flutterBinary : dartBinary;
    final watch = Stopwatch()..start();
    try {
      final result = await runProcess(
        binary,
        List<String>.of(pubGetArgs),
        workingDirectory: projectRoot,
      );
      watch.stop();
      final output = '${result.stdout}${result.stderr}'.trim();
      return PubPreResolveReport(
        ran: true,
        ok: result.exitCode == 0,
        binary: binary,
        args: List<String>.unmodifiable(pubGetArgs),
        elapsed: watch.elapsed,
        exitCode: result.exitCode,
        output: output,
      );
    } on ProcessException catch (e) {
      // The resolver could not START — nothing was proven broken. The
      // caller warns loudly; the environment may resolve elsewhere.
      return PubPreResolveReport(
        ran: false,
        ok: false,
        binary: binary,
        args: List<String>.unmodifiable(pubGetArgs),
        unavailableReason:
            '$binary could not be started: '
            '${e.message}',
      );
    } on ProcessTimeoutException catch (e) {
      // Bug #742: the child outlived the deadline and was killed — a real
      // failure the caller reports (never a silent pass).
      watch.stop();
      return PubPreResolveReport(
        ran: true,
        ok: false,
        binary: binary,
        args: List<String>.unmodifiable(pubGetArgs),
        elapsed: watch.elapsed,
        output: e.toString(),
      );
    }
  }
}
