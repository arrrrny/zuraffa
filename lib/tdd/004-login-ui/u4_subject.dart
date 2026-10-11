// GENERATED STUB — `zfa tdd gen U4` (spec 044-test-tdd-generation).
//
// behavior_id: U4
// source_criterion: FR-004, AuthGateway.signIn
// description: The system MUST map a successful auth attempt to a result carrying the user's email and a null error.
//
// This is a MINIMAL COMPILABLE STUB. It compiles cleanly (FR-011) but
// does NOT satisfy the behavior described above — the paired test will
// fail on first execution with an assertion-level failure (honest red).
// Replace this stub body with real implementation to make the test pass.
//
// The subject name is derived from the behavior id (`subject_u1`) and is
// deliberately snake_cased — the generator KNOWS the name it emits, so
// the lint its shape provably trips is suppressed here rather than
// renaming the contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

import 'login_domain.dart';

LoginResult subject_u4() {
  LoginResult gateway(String email, String password) =>
      LoginResult.success(email);
  return submitLogin(
    const LoginCredentials(email: 'user@example.com', password: 'longenough1'),
    gateway,
  );
}
