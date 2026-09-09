// GENERATED STUB — `zfa tdd gen contract:A1` (issue #1007).
//
// behavior_id: contract:A1
// source_criterion: LoginValidation.validate
// kind: contract
// target: subject_contract_a1
// description: LoginValidation.validate(email, password) -> LoginVerdict (usecase contract)
//
// CONTRACT SEAM (issue #1007): this file is where the declared contract
// `LoginValidation.validate(email arg0, password arg0) -> LoginVerdict`
// (usecase contract) gets its implementation. Implement the seam
// below — or wire it to the production method. The paired contract test
// enumerates the contract's cases and stays BLOCKED (never RED) until
// every case is satisfied.
library;

import 'login_domain.dart';

LoginVerdict validate(Object? email, Object? password) =>
    validateLogin(email! as String, password! as String);
