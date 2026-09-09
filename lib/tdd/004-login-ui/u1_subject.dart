// GENERATED STUB — `zfa tdd gen U1` (spec 044-test-tdd-generation
// + issue #1259 contract derivation).
//
// behavior_id: U1
// source_criterion: FR-001, LoginValidation.validate
// description: The system MUST treat an email as well-formed only when it contains a non-empty local part, an `@` separator, and a non-empty domain containing a `.`.
//
// CONTRACT-DERIVED SUBJECT (issue #1259): the signature below is
// derived from the spec's declared Layer Contract:
//
//     validate(email, password) -> LoginVerdict
//
// The declared request and result types are preserved above. A
// non-renderable declared type (an entity that does not exist yet)
// renders as `Object?` so the stub compiles cleanly (FR-011); replace
// it with the declared type when implementing. This is a MINIMAL
// COMPILABLE STUB: it does NOT satisfy the behavior — the paired test
// fails on first execution (honest red). Replace this stub body with
// the real implementation of the declared contract to make the test
// pass.
// Declared parameters: email: email, password: password (non-renderable declared types render as Object? until implemented)
//
// The subject name is derived from the behavior id and is deliberately
// snake_cased — the generator KNOWS the name it emits, so the lint its
// shape provably trips is suppressed here rather than renaming the
// contract surface (issue #1035).
// ignore_for_file: non_constant_identifier_names
library;

import 'login_domain.dart';

/// Subject for behavior U1 — declared contract:
/// `validate(email, password) -> LoginVerdict`.
///
/// Throws [UnimplementedError] until the real implementation lands.
LoginVerdict subject_u1(Object? email, Object? password) =>
    validateLogin(email! as String, password! as String);
