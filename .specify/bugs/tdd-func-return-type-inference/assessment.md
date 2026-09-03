# Bug Assessment: tdd func scaffolder return type stays int even when test expects String

- **Slug**: tdd-func-return-type-inference
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/920
- **Verdict**: likely valid, needs reproduction
- **Severity**: medium

## Report

When the entity-bearing plan (`zfa tdd wire U<n> --entity Task`) or `zfa tdd func` fires, the generated subject has return type `int` and returns `0` even when the behavior's paired test or behavior description indicates `String`, `bool`, `Map`, `List`, `Future`, or a custom class result.

## Symptom

Stub/wired subjects default to `int` and return `0`. While `expect(result, isNot(isA<UnimplementedError>()))` passes, semantic return types in generated functions do not match behavior descriptions (such as "returns a string" or "returns true").

## Reproduction

Check `zfa tdd func` and `zfa tdd wire` subject generation in `lib/src/plugins/tdd/commands/func_command.dart` and `make_command.dart`.

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/func_command.dart`
- `lib/src/plugins/tdd/commands/make_command.dart`
- `lib/src/plugins/tdd/services/generation_planner.dart`

## Root Cause Hypothesis

`func_command.dart` and `make_command.dart` infer or default return type to `int` without checking description keywords like `string`, `bool`, `true`, `false`, `list`, `map`, etc., or parsing return type clauses from description strings.

## Proposed Remediation

1. Introduce a helper to infer return type and default return expression from behavior description / return clauses (e.g. `String` -> `""`, `bool` -> `true`/`false`, `List` -> `const []`, `Map` -> `const {}`, `int` -> `0`, `dynamic` -> `null`).
2. Use this inference in `zfa tdd func` and `zfa tdd wire`.
3. Add unit tests in `test/plugins/tdd/` verifying return type derivation.

## Risks & Considerations

Existing generated tests expecting dynamic/non-error should continue to pass.
