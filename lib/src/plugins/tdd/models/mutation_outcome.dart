/// MutationOutcome and MutationGateDecision — the per-mutant
/// classification and per-audit gate decision (spec 044-test-tdd-generation,
/// FR-014, FR-016, FR-017, FR-019).
///
/// [MutationOutcome] is the four-valued classification for a single mutant:
/// killed, survived, timed out, or not assessed (when the mutation tool is
/// unavailable or the report is empty/incomplete/unparseable).
///
/// [MutationGateDecision] is the five-valued gate decision reported to CI:
/// pass, fail_survived, fail_timeout, preflight_red, not_assessed.
library;

/// Per-mutant classification.
enum MutationOutcome {
  /// The test suite caught the mutant (the test failed after the mutation).
  killed,

  /// The test suite did NOT catch the mutant (the test still passed).
  survived,

  /// The mutant's test run timed out — a separate bucket per upstream.
  timedOut,

  /// The mutant was not assessed (mutation tool unavailable, report empty/
  /// incomplete/unparseable). NEVER silently reported as a passing gate.
  notAssessed,
}

/// Per-audit gate decision.
enum MutationGateDecision {
  /// All mutants killed, no survivors, no timeouts, preflight green.
  pass,

  /// At least one mutant survived (the test suite missed a real mutation).
  failSurvived,

  /// No survivors but at least one timed-out mutant.
  failTimeout,

  /// The green-suite preflight failed; no mutation was performed.
  preflightRed,

  /// The mutation tool was unavailable or the report was empty/incomplete/
  /// unparseable. The audit could not reach a meaningful verdict.
  notAssessed;

  /// Stable lowercase snake_case label for the report (FR-019).
  String get label {
    switch (this) {
      case MutationGateDecision.pass:
        return 'pass';
      case MutationGateDecision.failSurvived:
        return 'fail_survived';
      case MutationGateDecision.failTimeout:
        return 'fail_timeout';
      case MutationGateDecision.preflightRed:
        return 'preflight_red';
      case MutationGateDecision.notAssessed:
        return 'not_assessed';
    }
  }

  /// Compute the gate decision from the bucket counts.
  ///
  /// Precedence (highest to lowest):
  /// 1. `notAssessed` (the audit could not reach a meaningful verdict).
  /// 2. `preflightRed` (the preflight failed before mutation could run).
  /// 3. `failSurvived` (ANY survived mutant fails the gate — strict policy).
  /// 4. `failTimeout` (no survivors, but at least one timed-out mutant).
  /// 5. `pass` (all killed, no survivors, no timeouts).
  static MutationGateDecision decide({
    required int killedCount,
    required int survivedCount,
    required int timedOutCount,
    required bool notAssessed,
    required bool preflightRed,
  }) {
    if (notAssessed) return MutationGateDecision.notAssessed;
    if (preflightRed) return MutationGateDecision.preflightRed;
    if (survivedCount > 0) return MutationGateDecision.failSurvived;
    if (timedOutCount > 0) return MutationGateDecision.failTimeout;
    return MutationGateDecision.pass;
  }
}
