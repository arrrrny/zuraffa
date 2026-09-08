/// Pure classification of a FAILED refactor re-proof attempt (spec 1333,
/// issue #1333).
///
/// The refactor re-proof shells out to `dart test` through
/// `SingleTestRunner.runSuite`; a transient Dart incremental kernel-cache
/// race (`Cannot retrieve length of file ... dart_test.kernel.<path>.dill`,
/// errno 2, exit 255) must NOT be counted as a genuine regression. This is
/// the re-proof tier of the red_classifier lesson: all transcript-grammar
/// parsing lives here, pure and unit-testable.
///
/// Decision order (first match wins):
///   1. process failed to start                        -> infraRunner
///   2. per-command timeout (bug #742 tier)            -> infraRunner
///   3. kernel-cache signature in the transcript       -> infraRunner
///   4. exit 255 (dart test VM/runner crash)           -> infraRunner
///   5. anything else (exit 1 with `[E]` names,
///      unparseable reds, other non-zero exits)        -> regression
///
/// `regression` means "declared regression immediately, no retry" — the
/// pre-issue-#1333 behavior, preserved for every failure mode the infra
/// signatures do not cover (FR-4 backward compatibility: a genuine
/// assertion failure regresses without burning retry suite runs).
library;

/// The two failure tiers a failed re-proof attempt can land in.
enum ReproofFailureClass {
  /// Infra-level runner failure: retried with a kernel-cache clear; never
  /// a regression. Exhausted retries yield `runner-error`.
  infraRunner,

  /// A genuine (or unparseable) red: declared regression immediately.
  regression,
}

/// The kernel-cache / runner-crash signature grammar (spec 1333): the
/// observed transient failure phrasing, case-insensitive. The sentence is
/// the issue's primary signature; `dart_test.kernel` only counts when the
/// same line also carries crash evidence; a `.dill` path co-occurring with
/// an ENOENT/errno-2 marker catches the variants the sentence does not cover.
final RegExp _kernelCacheSignature = RegExp(
  r'cannot retrieve length of file'
  r'|dart_test\.kernel[^\n]*(?:enoent|errno 2|no such file|cannot|failed)'
  r'|(?:enoent|errno 2|no such file|cannot|failed)[^\n]*dart_test\.kernel'
  r'|\.dill[^\n]*(?:enoent|errno 2|no such file)'
  r'|(?:enoent|errno 2|no such file or directory)[^\n]*\.dill',
  caseSensitive: false,
);

/// Whether a re-proof transcript carries a kernel-cache / runner-crash
/// signature (FR-1).
bool hasKernelCacheSignature(String output) =>
    _kernelCacheSignature.hasMatch(output);

/// The first transcript line carrying a kernel-cache / runner-crash
/// signature (for diagnostics), or null.
String? kernelCacheSignatureLine(String output) {
  for (final line in output.split('\n')) {
    if (_kernelCacheSignature.hasMatch(line)) {
      return line.trim();
    }
  }
  return null;
}

/// Classify one FAILED re-proof attempt into exactly one
/// [ReproofFailureClass].
ReproofFailureClass classifyReproofFailure({
  required int exitCode,
  required String output,
  required bool startedProcess,
  bool timedOut = false,
}) {
  // 1. The executable never launched: infrastructure failure (U15/A3).
  if (!startedProcess) {
    return ReproofFailureClass.infraRunner;
  }

  // 2. The runner was killed by the per-command timeout (bug #742): the
  //    suite state cannot be certified — infrastructure failure.
  if (timedOut) {
    return ReproofFailureClass.infraRunner;
  }

  // 3. The transcript carries the kernel-cache race signature: the runner
  //    crashed around its incremental kernel, not around the behavior.
  if (hasKernelCacheSignature(output)) {
    return ReproofFailureClass.infraRunner;
  }

  // 4. Exit 255 is dart test's VM/runner crash exit — never an assertion
  //    verdict (genuine assertion failures exit 1).
  if (exitCode == 255) {
    return ReproofFailureClass.infraRunner;
  }

  // 5. Everything else is a regression immediately (FR-4): exit 1 with
  //    parseable failing-test names, unparseable reds (the bug #922
  //    mutation M2 guard), and any other non-zero exit.
  return ReproofFailureClass.regression;
}

/// Failing-test identity from a `dart test` transcript: the names on
/// `mm:ss +N -M: <name> [E]` lines, sorted and de-duped. Shared by the
/// refactor command's preflight and this classifier (ONE copy of the
/// grammar — the red_classifier lesson).
List<String> parseFailingTestNames(String output) {
  final names = <String>{};
  for (final line in output.split('\n')) {
    // Match lines like `00:01 +0 -1: some test name [E]`.
    final m = RegExp(
      r'^\s*\d{2}:\d{2}\s+\+?\d*\s+-\d+:\s+(.+?)\s+\[E\]\s*$',
    ).firstMatch(line);
    if (m != null) {
      names.add(m.group(1)!);
    }
  }
  final sorted = names.toList()..sort();
  return sorted;
}

/// The audit tail of a re-proof transcript (FR-3): the last [maxChars]
/// characters on whole-line boundaries, prefixed `...(truncated)` when a
/// cut happened.
String reproofOutputTail(String output, {int maxChars = 2000}) {
  final trimmed = output.trim();
  if (trimmed.length <= maxChars) return trimmed;
  final start = trimmed.length - maxChars;
  // Snap forward to the next line start so the tail begins on a whole
  // line (no mid-line cut).
  final nl = trimmed.indexOf('\n', start);
  final cut = nl == -1 ? start : nl + 1;
  return '...(truncated)\n${trimmed.substring(cut)}';
}
