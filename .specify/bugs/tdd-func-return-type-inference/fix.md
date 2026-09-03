# Bug Fix: fix(tdd): tdd func scaffolder return type stays int even when test expects String

- **Slug**: tdd-func-return-type-inference
- **Fixed**: 2026-09-03
- **Branch**: fix/920-tdd-func-return-type-inference
- **Issue**: 920
- **Status**: applied

## Changes Made

1. Created `lib/src/plugins/tdd/services/subject_signature_deriver.dart` defining `deriveSubjectSignature` to infer return type (`String`, `bool`, `int`, `double`, `List`, `Map`) and minimal body expressions from behavior descriptions.
2. Updated `FuncCommand` (`lib/src/plugins/tdd/commands/func_command.dart`) to use `deriveSubjectSignature` and ensure process exit code is 0 on success / idempotent paths.
3. Updated `WireCommand` (`lib/src/plugins/tdd/commands/wire_command.dart`) to infer effective return type and body via `deriveSubjectSignature(description, forWire: true)` instead of hardcoding `return 0;`.
4. Added test `U-920` in `test/plugins/tdd/wire_command_test.dart` asserting that wired subjects derive `String` when description calls for string rendering.

## Verification

Ran:
- `dart test test/plugins/tdd/wire_command_test.dart test/plugins/tdd/commands/func_command_test.dart test/plugins/tdd/services/generation_planner_test.dart` -> All passed.
- `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/` -> No issues found.
