/// `ContractGate` — the MOCK-era suite against the real binding must stay
/// green (spec 913, phase 2).
///
/// The verdict is attribution-honest by construction: the baseline run
/// (mock binding, recorded BEFORE the rebind) is judged first — a red
/// baseline means the MOCK era broke the contract and the real impl is
/// never blamed for it. Only a green baseline + red real run attributes
/// the break to the real impl.
library;

/// The verdict the contract gate renders:
/// - green: the suite is green against both bindings — the swap holds.
/// - realBrokeContract: the suite was green on the mock binding and red
///   on the real binding — the real impl broke the contract.
/// - mockBrokeContract: the suite is red against the MOCK binding too —
///   the mock era (or its tests) was already broken; not the real impl's
///   fault.
enum ContractVerdict { green, realBrokeContract, mockBrokeContract }

/// One suite run observation (exit code + combined output).
class ContractRun {
  const ContractRun({required this.exitCode, required this.output});
  final int exitCode;
  final String output;
}

/// The gate's decision, with the attribution a verdict owes its reader.
class ContractGateResult {
  const ContractGateResult({
    required this.verdict,
    required this.attribution,
    required this.baseline,
    required this.realRun,
  });

  final ContractVerdict verdict;

  /// One human line naming WHICH side broke the contract.
  final String attribution;

  /// The mock-binding baseline run (before the rebind).
  final ContractRun baseline;

  /// The real-binding run (after the rebind).
  final ContractRun realRun;

  bool get isGreen => verdict == ContractVerdict.green;
}

class ContractGate {
  const ContractGate();

  /// Evaluate the two runs: [baseline] is the mock-binding run recorded
  /// BEFORE the rebind, [realRun] the same suite against the real
  /// binding AFTER it.
  ContractGateResult evaluate({
    required ContractRun baseline,
    required ContractRun realRun,
  }) {
    if (baseline.exitCode != 0) {
      return ContractGateResult(
        verdict: ContractVerdict.mockBrokeContract,
        attribution:
            'the mock era broke the contract: the MOCK-era suite is red '
            'against the MOCK binding too (baseline exit '
            '${baseline.exitCode}) — fix the mock or the tests before '
            'realizing; this is not the real impl\'s fault.',
        baseline: baseline,
        realRun: realRun,
      );
    }
    if (realRun.exitCode != 0) {
      return ContractGateResult(
        verdict: ContractVerdict.realBrokeContract,
        attribution:
            'the real impl broke the contract: the MOCK-era suite was '
            'green against the mock binding and is red against the real '
            'binding (exit ${realRun.exitCode}) — the swap is rolled '
            'back.',
        baseline: baseline,
        realRun: realRun,
      );
    }
    return ContractGateResult(
      verdict: ContractVerdict.green,
      attribution:
          'the mock-era suite stays green against the real binding — '
          'the contract holds on both sides.',
      baseline: baseline,
      realRun: realRun,
    );
  }
}
