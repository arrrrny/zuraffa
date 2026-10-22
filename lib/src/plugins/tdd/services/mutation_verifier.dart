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

import 'tdd_timeout.dart';

import '../models/mutation_survivor.dart';
export '../models/mutation_survivor.dart';

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
    this.survivors = const [],
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

  /// Per-mutant detail for every survived mutant (bug #837): the file and
  /// line the mutation_test v1.8+ markdown report lists under
  /// "Undetected mutations in file". Empty when nothing survived or no
  /// report was produced.
  final List<MutationSurvivor> survivors;

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

/// The exit code a child killed with SIGKILL reports on POSIX (-9).
const int _sigkillExitCode = -9;

/// Thrown when the mutation child was KILLED — the deadline kill (bug #742)
/// or any other signal death.
///
/// A killed run never finishes, so it never writes a report: the run has
/// NO score of its own. Publishing a number parsed from whatever report
/// happens to be on disk would publish a PREVIOUS run's score (issue
/// #1985), so a killed run is always reported as not-assessed, carrying
/// the child's exit code.
class MutationRunKilled implements Exception {
  MutationRunKilled(this.reason, {required this.exitCode});

  /// Human-readable reason — the audit report's `not_assessed_reason`.
  final String reason;

  /// The child's exit code: negative on POSIX (the signal number that
  /// killed it — e.g. -15 for SIGTERM, -9 for SIGKILL).
  final int exitCode;

  @override
  String toString() => reason;
}

/// Runs `dart run mutation_test <config>` and parses the markdown report.
class MutationVerifier {
  MutationVerifier({
    this.configPath = 'mutation-test.xml',
    this.outputDir = 'mutation-test-report',
    this.reportFormat = 'md',
    this.workingDirectory,
    Duration? timeout,
    this.dartBinary,
  }) : timeout = timeout ?? TddTimeouts.defaultMutationRun;

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

  /// The `dart` executable to invoke. Null (the production path) resolves
  /// `dart` from PATH; a test can point it at a stub so the child's fate
  /// (a clean exit, a signal death) is deterministic.
  final String? dartBinary;

  /// Hard deadline for the mutation run (bug #742): the child is killed
  /// (SIGKILL) at the deadline and a [ProcessTimeoutException] is thrown —
  /// the audit hangs never. Generous by design: the mutation run is the
  /// slowest TDD child (one test execution per mutant).
  final Duration timeout;

  /// Run the mutation audit. Returns a [MutationResult] with the parsed
  /// score. Throws [MutationToolUnavailable] if `dart` is not on PATH or
  /// the package is not installed. Throws [MutationConfigError] if the
  /// runner exits non-zero and produces no report (e.g. config not found,
  /// XML parse error).
  Future<MutationResult> run() async {
    final dartBin = dartBinary ?? await _resolveDartBinary();
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
    final reportPath = p.join(outArg, 'mutation-test-report.$reportFormat');

    // Issue #1985: the report path is per WORKING DIRECTORY, not per
    // feature — the previous feature's verify run left its report here.
    // A run that is killed never rewrites it, so the stale file would be
    // parsed as this run's score. Remove it BEFORE the child starts: a
    // run that produces no report then finds no report at all.
    final staleRemoved = await _removeStaleReport(reportPath);

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
    // Bug #742: the mutation run is under a hard deadline — the child is
    // killed at the deadline and a ProcessTimeoutException propagates to
    // the auditor, which maps it to NOT_ASSESSED.
    final result = await _runChild(dartBin, args, cwd);
    stopwatch.stop();

    final stdoutText = result.stdout.toString();
    final stderrText = result.stderr.toString();
    final exitCode = result.exitCode;

    if (exitCode < 0) {
      // Issue #1985: the child was killed by a signal (e.g. SIGTERM at the
      // deadline) — it never finished, so it wrote no report. Publishing
      // a score here would publish the PREVIOUS run's report as this
      // feature's.
      throw MutationRunKilled(
        'mutation run killed by signal ${-exitCode} (exit code $exitCode) — '
        'the child never finished, so no mutation score can be published',
        exitCode: exitCode,
      );
    }

    final reportFile = File(reportPath);
    final reportExists = await reportFile.exists();
    // Issue #1985: only a report THIS run produced may be parsed. When a
    // predecessor could not be removed, the file on disk is not ours.
    final usableReport = reportExists && staleRemoved;
    if (!usableReport && exitCode != 0) {
      throw MutationConfigError(
        'mutation_test exited with code $exitCode and produced no report. '
        'Stderr: ${stderrText.trim()}',
      );
    }

    final reportText = usableReport ? await reportFile.readAsString() : '';
    final counts = _parseCounts(reportText, stdoutText);

    return MutationResult(
      exitCode: exitCode,
      killedCount: counts.killed,
      survivedCount: counts.survived,
      timeoutCount: counts.timeout,
      elapsed: stopwatch.elapsed,
      reportPath: usableReport ? reportPath : null,
      stdoutText: stdoutText,
      stderrText: stderrText,
      survivors: parseMutationSurvivors(reportText),
    );
  }

  /// Runs the mutation child under the hard deadline.
  ///
  /// A child that outlives the deadline is KILLED (SIGKILL), so it never
  /// writes a report — the run has no score of its own (issue #1985).
  /// That is reported as [MutationRunKilled], never as a score parsed
  /// from the report a previous run left behind.
  Future<ProcessResult> _runChild(
    String dartBin,
    List<String> args,
    String cwd,
  ) async {
    try {
      return await runTimed(
        dartBin,
        args,
        workingDirectory: cwd,
        timeout: timeout,
        // Deliberately NOT runInShell: on POSIX that wraps the invocation in
        // `sh -c` with the arguments joined, so a config path containing a
        // space or shell metacharacter would be re-split or interpreted.
        // `dart` is resolved from PATH by the OS without a shell.
      );
    } on ProcessTimeoutException catch (e) {
      throw MutationRunKilled(
        'mutation run timed out: the ${e.timeout} deadline was reached and '
        'the child was killed (SIGKILL) — no report was produced, so no '
        'mutation score can be published',
        exitCode: _sigkillExitCode,
      );
    }
  }

  /// Removes the report a previous run left at [reportPath] (issue #1985).
  ///
  /// Returns true when no untrusted predecessor remains — either there
  /// was none, or it was removed. A report that could NOT be removed is
  /// a report this run must not claim, so the caller distrusts it.
  Future<bool> _removeStaleReport(String reportPath) async {
    try {
      final file = File(reportPath);
      if (!await file.exists()) return true;
      await file.delete();
      return !await file.exists();
    } on IOException {
      return false;
    }
  }

  Future<String?> _resolveDartBinary() async {
    // PATH lookup via which/where. We can't use Process.run('which')
    // directly because some platforms lack `which`; use `dart --version`
    // with a fallback. The probe itself is under a short deadline (bug
    // #742): a hanging `dart` binary is treated as unavailable.
    try {
      final r = await runTimed('dart', const [
        '--version',
      ], timeout: TddTimeouts.defaultProbe);
      if (r.exitCode == 0) return 'dart';
    } on ProcessException {
      // ignored — fall through to null
    } on ProcessTimeoutException {
      // A `dart --version` that never returns is an unusable toolchain.
      return null;
    }
    return null;
  }

  /// Parse killed / survived / timeout counts from the markdown report
  /// and stdout. The mutation_test package (v1.8.0+) emits these in
  /// multiple forms across versions; we scan for all known shapes:
  ///
  /// Report (markdown table rows):
  ///   "Mutants killed: 42" / "Mutants survived: 3" / "Mutants timed out: 0"
  ///   "Detected by: test 11" (killed) / "Undetected Mutations: 2" (survived)
  ///   "Timeouts: 0"
  ///
  /// Stdout (single summary line):
  ///   "Killed X, survived Y, timeout Z"
  ///   "OK: 2/13 (15.38%) mutations were not detected!" (survived)
  ///
  /// We scan both report and stdout for robustness.
  _Counts _parseCounts(String reportText, String stdoutText) {
    var killed = 0;
    var survived = 0;
    var timeout = 0;
    for (final source in [reportText, stdoutText]) {
      if (source.isEmpty) continue;
      // Killed: "killed: N" / "Mutants killed: N" / "Killed N"
      // OR "Detected by: test N" (mutation_test v1.8+ format).
      // Allow pipe `|` as separator for markdown table rows.
      final k = RegExp(
        r'(?:killed|Mutants killed|Killed|Detected by: \w+)[\s:|]+(\d+)',
        caseSensitive: false,
      ).firstMatch(source);
      // Survived: "survived: N" / "Mutants survived: N" / "Survived N"
      // OR "Undetected Mutations: N" / "Undetected: N" / markdown
      // table row "| Undetected | N |".
      final s = RegExp(
        r'(?:survived|Mutants survived|Survived|Undetected Mutations|Undetected)[\s:|]+(\d+)',
        caseSensitive: false,
      ).firstMatch(source);
      // The summary stdout line "OK: 2/13 (15.38%) mutations were not
      // detected!" — capture the numerator as the survived count.
      final s2 = RegExp(
        r'OK:\s*(\d+)/\d+',
        caseSensitive: false,
      ).firstMatch(source);
      // Timeout: "timed out: N" / "Mutants timed out: N" /
      // "Timeouts: N" / markdown "| Timeouts | N |".
      final t = RegExp(
        r'(?:timed?\s*out|Mutants timed out|Timeouts?)[\s:|]+(\d+)',
        caseSensitive: false,
      ).firstMatch(source);
      if (k != null) killed = int.tryParse(k.group(1)!) ?? killed;
      if (s != null) {
        survived = int.tryParse(s.group(1)!) ?? survived;
      } else if (s2 != null) {
        survived = int.tryParse(s2.group(1)!) ?? survived;
      }
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

/// Extract the survived mutants (file + line) from a mutation_test v1.8+
/// markdown report (bug #837).
///
/// Only lines under `## Undetected mutations in file : <path>` headings are
/// scanned, so the summary table (which also mentions counts) can never be
/// mistaken for a per-mutant entry.
List<MutationSurvivor> parseMutationSurvivors(String reportText) {
  final survivors = <MutationSurvivor>[];
  final fileHeader = RegExp(
    r'^## Undetected mutations in file\s*:\s*(.+?)\s*$',
    multiLine: true,
  );
  final lineEntry = RegExp(r'^Line\s+(\d+)\s*:', multiLine: true);
  final matches = fileHeader.allMatches(reportText).toList();
  for (var i = 0; i < matches.length; i++) {
    final file = matches[i].group(1)!.trim();
    final bodyStart = matches[i].end;
    final bodyEnd = i + 1 < matches.length ? matches[i + 1].start : null;
    final body = reportText.substring(bodyStart, bodyEnd ?? reportText.length);
    for (final m in lineEntry.allMatches(body)) {
      survivors.add(MutationSurvivor(file: file, line: int.parse(m.group(1)!)));
    }
  }
  return survivors;
}
