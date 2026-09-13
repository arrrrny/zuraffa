# TDD Test List — SPEC 1565 (func recognizes the contract-derived subject)

**Feature:** 1565-func-recognize-contract-derived-subject
**Tier:** fast (cloud-agent discipline — `dart test` default per `dart_test.yaml`)

## Unit behaviors (fast tier)

| id | test | asserts (SC) | state |
| -- | ---- | ------------ | ----- |
| U-1565-P1 | provenance: both markers present → `isContractDerivedGenStub` true | SC-1 | GREEN |
| U-1565-P2 | provenance: the gen header WITHOUT the contract-derived marker → false | SC-2 | GREEN |
| U-1565-P3 | provenance: the contract-derived marker without the gen header → false | SC-2 | GREEN |
| U-1565-P4 | rewritability: legacy bounded shapes (`int`/`String`/`Object?`, no-arg and parametrized) match `funcRewritableStubPattern` | SC-4 | GREEN |
| U-1565-P5 | rewritability: entity-typed signatures (`ScanSession`, `User login(AuthRequest request)`, `List<Task>`, `Task?`) do NOT match the bounded pattern | SC-1 | GREEN |
| U-1565-P6 | declaration: the broadened pattern recognizes every shape gen's contract-derived template emits | SC-1 | GREEN |
| U-1565-P7 | refusal classification: `funcWouldRefuseContractDerivedStub` true only for provenance + throw + non-rewritable | SC-1, SC-3 | GREEN |
| U-1565-1 | func on an existing-entity contract-derived stub (`ScanSession subject_u1()`) → exit 0, outcome `contract-derived-noop`, subject byte-identical | SC-1 | GREEN |
| U-1565-2 | func on a parametrized entity contract-derived stub (`User login(AuthRequest request)`) → exit 0, no-op, byte-identical | SC-1 | GREEN |
| U-1565-3 | func on an entity-typed subject WITHOUT the contract-derived marker → refusal (exit 1, `unrecognized`) | SC-2 | GREEN |
| U-1565-4 | func on a provenance-backed stub with a mangled declaration (block body) → refusal preserved | SC-2 | GREEN |
| U-1565-5 | func on an implemented contract-derived subject (no throw) → `already-implemented` untouched | SC-4 | GREEN |
| U-1565-6 | func on a generic entity return (`List<Task> scanTasks()`) → no-op success | SC-1 | GREEN |
| U-1565-7 | func on a legacy plain-function stub (`int subject_x() => throw ...`) → still `scaffolded` (the bounded path is untouched) | SC-4 | GREEN |
| U-1565-8 | planner: `skipFuncScaffold: true` → plan carries only the terminal `build` step (expressible) | SC-3 | GREEN |
| U-1565-9 | planner: default summary → func step kept (legacy + scalar contract-derived) | SC-4, SC-3 | GREEN |
| U-1565-10 | make: contract-derived subject → recorded generation commands carry NO `tdd func`, subject byte-identical, no func refusal in output | SC-3 | GREEN |
| U-1565-11 | make: scalar contract-derived subject → the func step REMAINS scheduled (declared-dummy path preserved) | SC-4, SC-3 | GREEN |

## Red evidence (recorded before implementation)

```
$ dart test test/plugins/tdd/services/subject_provenance_1565_test.dart test/plugins/tdd/commands/func_command_1565_test.dart test/plugins/tdd/services/generation_planner_1565_test.dart test/plugins/tdd/make_command_1565_test.dart
subject_provenance_1565_test.dart: Error: Couldn't resolve the package
  'zuraffa' ... 'package:zuraffa/src/plugins/tdd/services/subject_provenance.dart'
  → file does not exist (T5 not yet implemented).
func_command_1565_test.dart U-1565-1: Expected exitCode 0 → Actual 1
  (the pre-fix refusal: "subject carries an UnimplementedError in an
  unrecognized shape — refusing to rewrite a file this command did not
  generate." — the exact #1565 symptom, reproduced on the fixture).
generation_planner_1565_test.dart: Error: The named parameter
  'skipFuncScaffold' isn't defined (T7 not yet implemented).
make_command_1565_test.dart U-1565-10: the cycle log records
  `zfa tdd func` and the make ends generation-error pre-fix.
```

The red state is the bug itself: the func-level reds reproduce the issue's
symptom byte-for-byte, the planner/make reds are compile-time missing-API
evidence of the absent scheduling fix.
