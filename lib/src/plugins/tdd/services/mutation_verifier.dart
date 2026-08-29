/// `MutationVerifier` — runs `dart run mutation_test` against a config file
/// and parses the markdown report into a structured score.
///
/// Wires the `mutation_test` package (https://pub.dev/packages/mutation_test)
/// into the `zfa tdd verify` audit. Before this service existed, the spec
/// 041 verification phase fell back to a "deliberate-mutant spot check"
/// (manual mutants, hand-rolled assertions). The TDD profile now declares
/// mutation_test as the wired mutation tool — see
/// `.specify/memory/tdd-profile.md` and `specs/041-tdd-setup-plugin/tdd/
/// verification.md` (section 2).
///
/// The service shells out to `dart run mutation_test` because the upstream
/// package does not expose a stable programmatic API for invoking the
/// mutation runner (its public surface is the `mutation_test.dart` script
/// entry point). The shell boundary is honest: we capture stdout/stderr,
/// the exit code, and the generated markdown report, and surface them as a
/// [MutationResult].
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// The outcome of a single `zfa tdd verify` run.
class MutationResult {
  MutationResult({
    required this.exitCode,
    required this.killedCount,
    required this.survivedCount,
    required this.timeoutCount,
    required this.elapsed,
    required this.reportPath,
    required this.stdoutText,
    required this.stderrText,
  });

  /// `dart run mutation_test` exit code. 0 = all mutants either killed or
  /// no mutants generated. Non-zero = the runner crashed or one or more
  /// mutants survived (the package's own convention).
  final int exitCode;

  /// Mutants that the test suite caught (the test failed after the mutation).
  final int killedCount;

  /// Mutants that the test suite did NOT catch (the test still passed).
  final int survivedCount;

  /// Mutants whose test run timed out — treated as a separate bucket per
  /// the upstream docs.
  final int timeoutCount;

  /// Wall-clock seconds the runner took.
  final Duration elapsed;

  /// Absolute path to the generated markdown report, or null if no report
  /// was produced (e.g. config parse error before runner started).
  final String? reportPath;

  /// Captured stdout from `dart run mutation_test`.
  final String stdoutText;

  /// Captured stderr from `dart run mutation_test`.
  final String stderrText;

  /// Total mutants evaluated = killed + survived + timeout.
  int get totalMutants => killedCount + survivedCount + timeoutCount;

  /// Mutation score = killed / total (0..1). Returns 1.0 when total is 0
  /// (no mutants generated) — by convention, "no mutants" = nothing to
  /// catch, so the suite is vacuously strong.
  double get score {
    final t = totalMutants;
    return t == 0 ? 1.0 : killedCount / t;
  }

  /// True iff the audit passed the gate (no survivors, exit code 0).
  bool get passed => exitCode == 0 && survivedCount == 0;
}

/// Thrown when `dart run mutation_test` cannot be invoked at all (e.g. the
/// `dart` binary is not on PATH, or the package is not a dev_dependency).
class MutationToolUnavailable implements Exception {
  MutationToolUnavailable(this.reason);
  final String reason;

  @override
  String toString() => 'MutationToolUnavailable: $reason';
}

/// Thrown when the config file is missing or the runner rejected it before
/// producing a report.
class MutationConfigError implements Exception {
  MutationConfigError(this.reason);
  final String reason;

  @override
  String toString() => 'MutationConfigError: $reason';
}

/// Runs `dart run mutation_test <config>` and parses the markdown report.
class MutationVerifier {
  MutationVerifier({
    this.configPath = 'mutation-test.xml',
    this.outputDir = 'mutation-test-report',
    this.reportFormat = 'md',
    this.workingDirectory,
  });

  /// Path to the `mutation-test.xml` config relative to [workingDirectory]
  /// (or absolute). Defaults to `mutation-test.xml` at the repo root.
  final String configPath;

  /// Directory to receive the generated report. Defaults to
  /// `mutation-test-report` (gitignored; see `.gitignore`).
  final String outputDir;

  /// Report format. `md` keeps the parsed-score logic in this service
  /// simple; `html` is generated alongside by the upstream runner when
  /// `-f all` is requested. We pin `md` here.
  final String reportFormat;

  /// Working directory for the subprocess. Defaults to
  /// `Directory.current.path`.
  final String? workingDirectory;

  /// Run the mutation audit. Returns a [MutationResult] with the parsed
  /// score. Throws [MutationToolUnavailable] if `dart` is not on PATH or
  /// the package is not installed. Throws [MutationConfigError] if the
  /// runner exits non-zero and produces no report (e.g. config not found,
  /// XML parse error).
  Future<MutationResult> run() async {
    final dartBin = await _resolveDartBinary();
    if (dartBin == null) {
      throw MutationToolUnavailable(
        '`dart` binary not found on PATH. The `mutation_test` package is '
        'invoked as `dart run mutation_test`; the `dart` SDK is required.',
      );
    }

    final cwd = workingDirectory ?? Directory.current.path;
    final configFile = File(p.join(cwd, configPath));
    if (!await configFile.exists()) {
      throw MutationConfigError(
        'mutation-test config not found at ${configFile.path}. '
        'Expected a `<mutations version="1.0">` XML document. See '
        'mutation-test.xml at the repo root for the canonical example.',
      );
    }

    final outArg = p.join(cwd, outputDir);
    final args = <String>[
      'run',
      'mutation_test',
      configPath,
      '-f',
      reportFormat,
      '-o',
      outArg,
    ];

    final stopwatch = Stopwatch()..start();
    final result = await Process.run(
      dartBin,
      args,
      workingDirectory: cwd,
      // Deliberately NOT runInShell: on POSIX that wraps the invocation in
      // `sh -c` with the arguments joined, so a config path containing a
      // space or shell metacharacter would be re-split or interpreted.
      // `dart` is resolved from PATH by the OS without a shell.
    );
    stopwatch.stop();

    final stdoutText = result.stdout.toString();
    final stderrText = result.stderr.toString();
    final exitCode = result.exitCode;

    final reportPath = p.join(outArg, 'mutation-test.$reportFormat');
    final reportFile = File(reportPath);
    final reportExists = await reportFile.exists();
    if (!reportExists && exitCode != 0) {
      throw MutationConfigError(
        'mutation_test exited with code $exitCode and produced no report. '
        'Stderr: ${stderrText.trim()}',
      );
    }

    final reportText = reportExists ? await reportFile.readAsString() : '';
    final counts = _parseCounts(reportText, stdoutText);

    return MutationResult(
      exitCode: exitCode,
      killedCount: counts.killed,
      survivedCount: counts.survived,
      timeoutCount: counts.timeout,
      elapsed: stopwatch.elapsed,
      reportPath: reportExists ? reportPath : null,
      stdoutText: stdoutText,
      stderrText: stderrText,
    );
  }

  Future<String?> _resolveDartBinary() async {
    // PATH lookup via which/where. We can't use Process.run('which')
    // directly because some platforms lack `which`; use `dart --version`
    // with a fallback.
    try {
      final r = await Process.run('dart', ['--version']);
      if (r.exitCode == 0) return 'dart';
    } on ProcessException {
      // ignored — fall through to null
    }
    return null;
  }

  /// Parse killed / survived / timeout counts from the markdown report.
  /// The mutation_test markdown report's summary section uses lines like:
  ///   "Mutants killed: 42"
  ///   "Mutants survived: 3"
  ///   "Mutants timed out: 0"
  /// In addition, the stdout from `dart run mutation_test` ends with a line
  /// like "Killed X, survived Y, timeout Z". We scan both for robustness.
  _Counts _parseCounts(String reportText, String stdoutText) {
    var killed = 0;
    var survived = 0;
    var timeout = 0;
    for (final source in [reportText, stdoutText]) {
      if (source.isEmpty) continue;
      final k = RegExp(
        r'(?:killed|Mutants killed|Killed)[:\s]+(\d+)',
        caseSensitive: false,
      ).firstMatch(source);
      final s = RegExp(
        r'(?:survived|Mutants survived|Survived)[:\s]+(\d+)',
        caseSensitive: false,
      ).firstMatch(source);
      final t = RegExp(
        r'(?:timed?\s*out|Mutants timed out|Timeout)[:\s]+(\d+)',
        caseSensitive: false,
      ).firstMatch(source);
      if (k != null) killed = int.tryParse(k.group(1)!) ?? killed;
      if (s != null) survived = int.tryParse(s.group(1)!) ?? survived;
      if (t != null) timeout = int.tryParse(t.group(1)!) ?? timeout;
      if (killed != 0 || survived != 0 || timeout != 0) break;
    }
    return _Counts(killed, survived, timeout);
  }
}

class _Counts {
  const _Counts(this.killed, this.survived, this.timeout);
  final int killed;
  final int survived;
  final int timeout;
}
