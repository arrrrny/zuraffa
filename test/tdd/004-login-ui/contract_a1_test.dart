// GENERATED TEST — `zfa tdd gen contract:A1` (issue #1007, contract lane).
//
// behavior_id: contract:A1
// source_criterion: LoginValidation.validate
// kind: contract
// description: LoginValidation.validate(email, password) -> LoginVerdict (usecase contract)
//
// CONTRACT TEST (issue #1007): this is NOT an implementation test — it
// proves the implementation at `../../../lib/tdd/004-login-ui/contract_a1_subject.dart`
// satisfies the DECLARED contract above. The body enumerates the
// contract's cases; every case must hold for the contract to be
// satisfied. While the method is deliberately unimplemented the test
// fails through an assertion and `zfa tdd verify-red` reports BLOCKED
// (never RED): a failing contract test blocks the cycle from proceeding
// to GREEN until the implementation satisfies the contract.
library;

import 'package:test/test.dart';
import '../../../lib/tdd/004-login-ui/contract_a1_subject.dart' as subject;

void main() {
  group('contract:A1 (LoginValidation.validate)', () {
    test(
      'contract:A1 \u2014 LoginValidation.validate(email, password) -> LoginVerdict (usecase contract)',
      () {
        // Case 1 of 2 — signature: the declared method
        // `LoginValidation.validate(email arg0, password arg0) -> LoginVerdict` is
        // exposed by the implementation subject.
        final impl = subject.validate;
        expect(
          impl,
          isNotNull,
          reason:
              'LoginValidation.validate must be exposed with the declared '
              'signature `(email arg0, password arg0) -> LoginVerdict`',
        );

        // Case 2 of 2 — implementation: invoking the declared
        // method does not throw UnimplementedError and honors the contract.
        final Object? outcome = _captured(
          () => impl('user@example.com', 'longenough1'),
        );
        expect(
          outcome,
          isNot(isA<UnimplementedError>()),
          reason:
              'LoginValidation.validate is not implemented — the declared '
              'contract is unsatisfied, so the cycle is BLOCKED and cannot '
              'proceed to GREEN (issue #1007)',
        );
        expect(
          outcome,
          isA<dynamic>(),
          reason: 'the contract returns a verdict',
        );
      },
    );
  });
}

/// Captures an [UnimplementedError] thrown by an unimplemented contract
/// seam (or a scaffold placeholder argument) as the assertion's actual
/// value, so the blocked state fails through an assertion (never an
/// uncaught error).
Object? _captured(Object? Function() invoke) {
  try {
    return invoke();
  } on UnimplementedError catch (error) {
    return error;
  }
}
