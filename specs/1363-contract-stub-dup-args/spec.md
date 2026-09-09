**Template Version**: `zuraffa-1.0`

# Spec: 1363-contract-stub-dup-args

GitHub issue: arrrrny/zuraffa#1363 (verify-misfire / missing-integration)

## Summary

`zfa tdd gen` emits an uncompilable contract subject stub for multi-param
declared contracts: `ContractParam.parse` fell back to `arg0` for EVERY
bare-name cell, so `validate(email, password) -> LoginVerdict` generated
`validate(Object? arg0, Object? arg0)` — duplicate_definition at analysis,
and the load-error smeared the verify-red batch classification
(contract:A1 load-error poisons honestly-red siblings). The generated
test's signature summary echoed the defect.

## Locked decisions

1. Bare identifier cells are declared NAMES (the Layer Contracts grammar:
   `validate(email, password)`): the stub emits `dynamic email, dynamic
   password` — the declared parameter names survive, per the issue's
   "or better, the declared parameter names" remedy.
2. Bare non-identifier cells (unnamed generic types: `List<int>`,
   `Map<String, int>`) are unnamed TYPES: positional names `arg$index`
   (the issue's primary remedy) — per-position numbering, never the same
   name twice.
3. Typed cells (`String email`, `int a`) behave exactly as before.
4. The signature summary in the generated TEST renders the same parsed
   params, so the echo is unique by construction.
5. The two-signal `_argN()` placeholder machinery (issue #1323) is
   untouched — the writer's helper numbering already indexes by param
   position.

## Functional requirements

- **FR-1**: a multi-param contract with bare-name and typed cells emits
  a compilable subject with UNIQUE parameter names; declared names
  survive for bare and typed cells.
- **FR-2**: unnamed generic-type cells get positional `arg<i>` names.
- **FR-3**: the generated test's param summary is unique-by-construction.

## Acceptance scenarios

1. `validate(email, password)` → subject declares `dynamic email,
   dynamic password` (B1).
2. `sum(int a, int b)` → `int a, int b` unchanged (B2).
3. `process(List<int>, Map<String, int>)` → `arg0, arg1` (B3).
4. The test file's summary carries unique names (B4).
5. Mixed row `send(int amount, currency, AuditTrail trail)` → all names
   unique (B5).

## Success criteria

- **SC-001**: gen-emitted contract pairs compile (no
  duplicate_definition) and verify-red certifies honestly-red instead of
  load-error for the repro.
- **SC-002**: The tdd plugin suites stay green.

## Assumptions

- `dynamic` is the honest stub type for bare-name cells (the contract
  test's representative-argument machinery and the #1323 hand-delta seam
  cover type-refinement later).
