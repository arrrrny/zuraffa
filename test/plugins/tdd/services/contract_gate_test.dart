// Fast unit tests for `ContractGate` — the MOCK-era suite verdict
// attribution (spec 913, T002: U8-U10).
//
//   U8: green verdict when the suite is green against both bindings.
//   U9: verdict real-broke-contract when the baseline (mock) run is
//       green and the real run is red — the real impl broke it.
//   U10: verdict mock-broke-contract when the baseline run is already
//        red — the mock era broke the contract, not the real impl.
library;

import 'package:test/test.dart';
import 'package:zuraffa/src/plugins/tdd/services/contract_gate.dart';

void main() {
  const gate = ContractGate();

  test('U8: green when the suite is green against both bindings', () {
    final result = gate.evaluate(
      baseline: const ContractRun(exitCode: 0, output: 'all green'),
      realRun: const ContractRun(exitCode: 0, output: 'all green'),
    );

    expect(result.verdict, ContractVerdict.green);
    expect(result.isGreen, isTrue);
    expect(result.attribution, contains('green'));
  });

  test('U9: real-broke-contract when baseline green and real red', () {
    final result = gate.evaluate(
      baseline: const ContractRun(exitCode: 0, output: 'all green'),
      realRun: const ContractRun(
        exitCode: 1,
        output: 'Expected: <2> Actual: <3>',
      ),
    );

    expect(result.verdict, ContractVerdict.realBrokeContract);
    expect(result.isGreen, isFalse);
    expect(
      result.attribution,
      allOf(contains('real'), contains('broke')),
      reason: 'the verdict must name the side that broke the contract',
    );
    expect(result.realRun.exitCode, 1);
    expect(result.baseline.exitCode, 0);
  });

  test('U10: mock-broke-contract when the baseline run is already red', () {
    final result = gate.evaluate(
      baseline: const ContractRun(
        exitCode: 1,
        output: 'Expected: <2> Actual: <3>',
      ),
      realRun: const ContractRun(exitCode: 1, output: 'also red'),
    );

    expect(result.verdict, ContractVerdict.mockBrokeContract);
    expect(result.isGreen, isFalse);
    expect(
      result.attribution,
      allOf(contains('mock'), contains('broke')),
      reason: 'a red baseline must never be blamed on the real impl',
    );
  });
}
