// GENERATED STUB — `zfa tdd gen A6` (spec 044-test-tdd-generation).
//
// behavior_id: A6
// source_criterion: AC-6
// description: the result is a failure carrying a non-empty error reason.
//
// This is a MINIMAL COMPILABLE acceptance-scenario stub. It compiles
// cleanly (FR-011) but does NOT satisfy the behavior described above —
// the paired test will fail on first execution with an assertion-level
// failure (honest red). The acceptance subject intentionally does NOT
// reference any entity/use case/repository (FR-004): it stands alone.
// Replace this stub body with real implementation to make the test pass.
//
// The subject name is derived from the behavior id (`subject_a1`) and is
// deliberately snake_cased — the generator KNOWS the name it emits, so
// the lint its shape provably trips is suppressed here rather than
// renaming the contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

import 'login_domain.dart';

LoginResult subject_a6() {
  LoginResult gateway(String email, String password) =>
      const LoginResult.failure('invalid credentials');
  return submitLogin(
    const LoginCredentials(email: 'user@example.com', password: 'longenough1'),
    gateway,
  );
}
