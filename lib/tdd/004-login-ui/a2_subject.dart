// GENERATED STUB — `zfa tdd gen A2` (spec 044-test-tdd-generation).
//
// behavior_id: A2
// source_criterion: AC-2
// description: the verdict is invalid with a reason naming the email field.
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

/// Scenario runner for behavior A2.
///
/// Throws [UnimplementedError] until the real implementation lands.
// The scenario pin is deliberately ASYMMETRIC (mutation-audit remediation,
// spec 1136 verify pass): the password 'a@b.co' is a WELL-FORMED email but
// fails the 8-character policy, so swapping the arguments changes the
// verdict (swapped: valid) — the argument ORDER stays observable to the
// acceptance test.
LoginVerdict subject_a2() => validateLogin('plainaddress', 'a@b.co');
