/// `classify` — pure six-way classification of a runner transcript
/// (spec 046-tdd-verify-red, FR-004, FR-005, T004; decision order per
/// research.md Decision 3).
///
/// Rule order (first match wins):
///   1. process failed to start                     -> runner-error
///   2. load signature (unreadable file/import)     -> load-error
///   3. compile signature (CFE diagnostics)         -> compile-error
///   4. executed-test count other than exactly 1    -> runner-error
///      (load/compile already won above: signature beats count, U8)
///   5. exit 0, skip markers only                   -> skipped
///   6. exit 0                                      -> unexpected-green
///   7. exit != 0 with assertion signature          -> assertion
///   8. anything else                               -> runner-error
///
/// All parsing lives here (pure, unit-testable) — the same lesson
/// `MutationVerifier` paid for: never scatter output-grammar regexes
/// across call sites.
library;

import '../models/red_classification.dart';

/// Classify one runner invocation into exactly one [RedClassification].
RedClassification classify(RunRecord record) {
  // 1. The executable never launched: infrastructure failure.
  if (!record.startedProcess) {
    return RedClassification.runnerError;
  }

  // 1b. The runner was killed by the per-command timeout (bug #742): the
  //     target test never finished, so nothing about the behavior was
  //     observed — infrastructure failure, never a certified red.
  if (record.timedOut) {
    return RedClassification.runnerError;
  }

  final output = record.output;

  // 2. Load failure: the test file (or an import) could not be READ.
  //    `dart test` reports both missing files and compile errors under a
  //    "Failed to load" wrapper, so the discriminator is the inner
  //    signature: a read-level marker means load, CFE diagnostics mean
  //    compile.
  if (_hasLoadSignature(output)) {
    return RedClassification.loadError;
  }

  // 3. Compile failure: CFE diagnostics ("file:line:col: Error: ...",
  //    "Compilation failed"), with or without the load wrapper.
  if (_hasCompileSignature(output)) {
    return RedClassification.compileError;
  }

  // 4. The runner must have executed EXACTLY the target test (FR-005).
  //    A blended run (2+ results) or an empty run (0) is rejected; an
  //    unparseable transcript cannot prove a single-test run either.
  final count = record.testCount;
  if (count == null || count != 1) {
    return RedClassification.runnerError;
  }

  // 5/6. Green side of the loop.
  if (record.exitCode == 0) {
    return _hasSkipMarkers(output)
        ? RedClassification.skipped
        : RedClassification.unexpectedGreen;
  }

  // 7/8. Red side: only an assertion signature makes the red honest.
  return _hasAssertionSignature(output)
      ? RedClassification.assertion
      : RedClassification.runnerError;
}

// ---------------------------------------------------------------------
// Transcript grammar (dart test / flutter test share package:test's
// reporter). Anchored to real captured output; see
// test/plugins/tdd/red_classifier_test.dart for the fixtures.
// ---------------------------------------------------------------------

final RegExp _progressLine = RegExp(
  r'^\d\d:\d\d \+(\d+)(?: -(\d+))?(?: ~(\d+))?:',
  multiLine: true,
);

final RegExp _readFailure = RegExp(
  r'Does not exist|Error when reading|No such file or directory',
);

final RegExp _cfeDiagnostic = RegExp(
  r'\S+:\d+:\d+:?\s*Error:|Compilation failed|CompilationError',
);

final RegExp _assertionSignature = RegExp(
  r'Expected:.*\n\s*Actual:|TestFailure',
);

bool _hasLoadSignature(String output) {
  if (!output.contains('Failed to load')) return false;
  // Read-level markers dominate CFE diagnostics inside the wrapper.
  if (_readFailure.hasMatch(output)) return true;
  // "Failed to load" with no deeper diagnostic is still a load failure.
  return !_cfeDiagnostic.hasMatch(output);
}

bool _hasCompileSignature(String output) => _cfeDiagnostic.hasMatch(output);

bool _hasSkipMarkers(String output) =>
    output.contains('All tests skipped') ||
    output.contains('Skip:') ||
    RegExp(r'^\d\d:\d\d \+\d+ ~\d+:', multiLine: true).hasMatch(output);

bool _hasAssertionSignature(String output) =>
    _assertionSignature.hasMatch(output);

// ---------------------------------------------------------------------
// Executed-test counting
// ---------------------------------------------------------------------

/// Parse the number of executed tests (passed + failed + skipped) from a
/// runner transcript, using the LAST progress line's cumulative counters.
///
/// Returns 0 for an explicit "No tests ran." transcript and `null` when
/// no progress line can be found at all (unparseable).
int? parseExecutedTestCount(String output) {
  if (output.contains('No tests ran.')) return 0;
  final matches = _progressLine.allMatches(output).toList();
  if (matches.isEmpty) return null;
  final last = matches.last;
  final passed = int.parse(last.group(1)!);
  final failed = last.group(2) == null ? 0 : int.parse(last.group(2)!);
  final skipped = last.group(3) == null ? 0 : int.parse(last.group(3)!);
  return passed + failed + skipped;
}
