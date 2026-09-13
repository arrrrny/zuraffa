# Test List: 1541-contract-harness-declared-shape-args

Derived LLM-guided (fallback path — this repo is the zfa tool itself; no
`.zfa.json` self-wiring). Outer-loop acceptance coverage rides the
slow-tier e2e; the fast tier pins the render surface. MVP-first ordering
matches tasks.md (U-1541-1..3 are the red-green MVP core).

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1541-1 | a contract behavior with a `dynamic` declared parameter (`Logger.logger(dynamic subsystem) -> Logger`) renders a Case 2 invocation passing the `_arg0()` scaffold placeholder (never the bare `null` literal), with the placeholder helper's `UnimplementedError` instructing `provide a representative ... value for the ... contract test` and the SCAFFOLD PLACEHOLDERS comment naming the `dynamic` declared type | FR-001, SC-1 | GREEN |
| U-1541-2 | every parseable contract render emits a `_captured` helper with a catch-all arm (`on Object`): an `ArgumentError`, `TypeError`, or any other thrown error becomes the assertion's actual value — nothing escapes uncaught into the runner transcript | FR-002, SC-2 | GREEN |
| U-1541-3 | the scalar-return render guards Case 3 on the `_rejection` capture SIGNAL (`if (_rejection == null)`): the `expect(outcome, isA<...>())` assertion runs only when nothing was captured, with the named satisfied-with-rejection comment; the Case 1/2 text, order, and `isNot(isA<UnimplementedError>())` pin stay unchanged, and the nullable complex type still resolves to `null` | FR-003, FR-004, SC-1, SC-4 | GREEN |
| U-1541-4 | slow-tier e2e: an argument-validating seam (throws `ArgumentError` for the scaffold's representative argument) runs the generated contract test against the real runner to a PASS (exit 0) and verify-red grades `classification=unexpected-green` — the contract satisfied WITHOUT shimming the seam | FR-002, FR-004, SC-2, SC-3 | GREEN |
| U-1541-5 | slow-tier e2e: the deliberately unimplemented seam STILL grades `classification=blocked` with the `contract-blocked.A1.json` receipt (the BLOCKED path byte-unchanged); a non-validating implemented seam keeps passing the return-type case normally | FR-003, SC-3, SC-4 | GREEN |
| U-1541-6 | the #1513 golden fixture is regenerated from the updated writer and the byte-comparison test passes (the `int`-param arguments survive; the render drift is the documented captured-error/Case-3-guard change) | FR-006, SC-5 | GREEN |
| U-1541-7 | no NEW analyzer issues against the pre-change baseline (112 pre-existing infos) and the changed-file test loop passes in the fast tier | FR-005, SC-4 | GREEN |
| U-1541-8 | review finding 1: declared types the seam renders verbatim (`List<T>`, `Set<T>`, `Map<K, V>`, `Iterable<T>`, `Future<T>`, `Stream<T>`) render representative literals (`<T>[]`, `<T>{}`, `<K, V>{}`, `const Stream.empty()`, `Future<T>.value(...)`) instead of the `Object?` placeholder — the pair LOADS and reaches the named BLOCKED surface; `List<dynamic>` settles its inner type in the literal; `Future<dynamic>` nests the inner-typed placeholder; a non-renderable inner type keeps the placeholder (the seam parameter is `Object?` there) | FR-001, SC-1 | GREEN |
| U-1541-9 | review finding 2: the Case 3 guard keys on the `_rejection` capture signal, never the outcome runtime type — a validating Error/Exception rejection skips the return-type assertion (satisfied-with-rejection), a thrown RAW value (even matching the declared return type) is surfaced as an assertion failure, a returned value still type-checks, and renders without a return-type case emit no rejection signal (no unread declaration) | FR-004, SC-2 | GREEN |

## Layer contracts

```yaml
# fr: FR-001
contract_test_writer.dart: _representativeArg resolves dynamic/empty declared types to the _argN() scaffold placeholder seam (unit-lane parity), never the bare null literal for those types; declared types the seam renders verbatim (List<T>/Set<T>/Map<K,V>/Iterable<T>/Future<T>/Stream<T>) resolve representative literals instead (review finding on #1558)
# fr: FR-002, FR-003
contract_test_writer.dart: the emitted _captured helper catches ALL errors (on Object), records the thrown value in the _rejection signal; UnimplementedError keeps its dedicated arm and doc split (BLOCKED vs satisfied-with-rejection)
# fr: FR-004
contract_test_writer.dart: _render guards the return-type case (Case 3) on the captured-_rejection SIGNAL (if (_rejection == null)), surfaces a thrown RAW value via the Error/Exception assertion, and emits no rejection signal on two-case renders; Case 1/2 pins byte-unchanged
# fr: FR-006
test/fixtures/baseline_outputs/bug_1513_contract_default_render.txt: regenerated golden matches the updated default render byte for byte
```

## Key entities

```yaml
ContractTestWriter: the contract test scaffold writer; owns _representativeArg, the emitted _captured, the _rejection signal, and the Case 3 guard
RepresentativeArg: the per-parameter argument expression resolver (scalars -> literals; renderable generics -> typed literals / Future.value / Stream.empty; dynamic/empty + complex -> _argN() placeholder; nullable complex -> null)
_captured: the emitted capture helper turning ANY thrown error into the assertion's actual value and recording it in the _rejection signal
ContractDeclaration/ContractParam: the parsed declared shape (unchanged parsers)
```

## External dependencies

(none — the fast-tier pins render templates in-process; the slow-tier e2e
spawns a real `dart test` subprocess in a temp fixture project exactly
like the #1007 e2e harness.)
