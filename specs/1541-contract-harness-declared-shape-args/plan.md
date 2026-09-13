**Template Version**: `zuraffa-1.0`

# Plan: 1541-contract-harness-declared-shape-args

## Technical Context

- **Language/toolchain**: pure Dart CLI (Dart SDK ^3.11.0); the contract
  lane writes PLAIN DART test scaffolds via string templates (no
  code_builder for this surface); tests run under the `test` package with
  the repo's two-tier discipline (fast tier default, slow-tier e2e tagged
  `slow` spawning a real `dart test` subprocess).
- **Feature surface** (issue #1541 hard constraint: the contract test
  harness and its `_captured` error handling ONLY — the verify-red batch
  classifier, the blocked verdict, the contract-blocked receipt, the run
  driver's state machine, the contract SEAM writer, the unit/acceptance
  lanes, and the golden harness writer are untouched):
  - `lib/src/plugins/tdd/services/contract_test_writer.dart` —
    `ContractTestWriter._render` + the module-level `_representativeArg`
    resolver and the emitted `_captured` helper:
    - **dynamic param scaffolding**: `_representativeArg` maps the
      `dynamic`/empty declared type to the bare literal `null` today. The
      fix makes it fall through to the `_arg$index()` scaffold placeholder
      seam the writer already emits for non-renderable complex types — the
      `_render` placeholder scan (`arg.startsWith('_arg')`) then picks the
      parameter up automatically, so the SCAFFOLD PLACEHOLDERS comment and
      the `_argN()` helper (whose `UnimplementedError` instructs
      `provide a representative ... value for the ... contract test`) are
      emitted for `dynamic` params exactly like the unit lane's
      `provide a representative argument` stubs
      (behavior_test_writer.dart:506). The placeholder's throw is CAUGHT by
      `_captured`, so the scaffold's red stays at the assertion level.
    - **`_captured` error handling**: the emitted helper catches ONLY
      `UnimplementedError` today. The fix adds the catch-all arm
      (`on Object catch (error) => error`), making every thrown error —
      `ArgumentError` from a validating implementation, `TypeError` from a
      cast (`null as String`), anything else — the assertion's actual
      value. `UnimplementedError` keeps its dedicated arm (documentation
      value: the two outcome classes stay named in the template), and the
      doc comment states the split: `UnimplementedError` drives BLOCKED via
      the Case 2 assertion; any other captured error is a
      satisfied-with-rejection (the seam is implemented and validating).
    - **declared-shape argument generation / Case 3 guard**: the return-
      type case (Case 3, emitted only for non-nullable scalar returns) is
      wrapped in a guard that runs the `expect(outcome, isA<...>())`
      assertion only when the capture SIGNAL records no rejection
      (`if (_rejection == null)` — `_captured` records the thrown value;
      PR #1558 review: the signal replaces the old runtime-type guess
      `outcome is! Error && outcome is! Exception`, which mistook a thrown
      raw value of the declared return type for a real return). A captured
      Error/Exception rejection passes Case 2
      (`isNot(isA<UnimplementedError>())` — an `ArgumentError` satisfies it
      verbatim) and skips Case 3 with a named comment (issue #1541
      satisfied-with-rejection), so the test passes and verify-red grades
      it out of the blocked class; a thrown RAW value (neither an `Error`
      nor an `Exception`) fails Case 3's Error/Exception assertion —
      surfaced honestly, never a silent green. The `_rejection` signal and
      its reader are emitted together: a two-case render (non-scalar
      return, no Case 3) carries neither, so no unread declaration leaks
      an analyzer warning. Case 1/Case 2 text, order, and the
      `isNot(isA<UnimplementedError>())` pin are byte-unchanged (the #1007
      fast-tier suite pins them).
    - **renderable declared types get literals (PR #1558 review)**: the
      resolver now resolves declared types the seam renders VERBATIM
      (`List<T>`, `Set<T>`, `Map<K, V>`, `Iterable<T>`, `Future<T>`,
      `Stream<T>`) to representative literals (`<T>[]`, `<T>{}`,
      `<K, V>{}`, `const Stream.empty()`, `Future<T>.value(...)`, the
      value-less form for `Future<void>`). The `_argN()` placeholder's
      `Object?` return does not compile against those declared parameter
      types, so the pre-fix pair failed to LOAD (verify-red could only
      grade a load/runner error, never the named BLOCKED verdict).
      `Future<dynamic>` nests the inner-typed placeholder (`_argN()` is
      caught at invocation, the BLOCKED surface holds); a declared type
      with a non-renderable inner (`List<Product>`) keeps the placeholder
      (the seam parameter is `Object?` there, the placeholder stays
      assignable).
  - `test/fixtures/baseline_outputs/bug_1513_contract_default_render.txt` —
    the #1513 byte-stability golden: REGENERATED in the same change (the
    captured-error doc comment and the guarded Case 3 alter the default
    render); its `int`-parameter arguments (`impl(0, 0)`) are unaffected by
    the dynamic-param fix, so the fixture keeps pinning the scalar path.
- **Grading path (NOT changed, read-only context)**:
  `verify_red_command.dart`'s `_classifyBatchBehavior` grades a failing
  segment by its assertion signature (`Expected:` / `Actual:` /
  `TestFailure` → `assertion`, else `runner-error`); with FR-002 every
  contract-test failure carries the signature (the failure is an
  EXPECT), so the `runner-error` classification becomes unreachable from
  the contract scaffold. A passing contract test grades
  `unexpected-green` (the skip transition the run driver already handles).
- **Related**: #1007 (contract lane origin), #1363 (stub arg uniqueness),
  #1443 (void seam renderability), #1513 (flutter imports + the golden
  this change regenerates), #991/#1323 (unit-lane representative args).

## Key decisions

- **Both issue remedies, not either**: the issue lists the declared-shape
  argument (criterion 1) OR the catch-all capture (criterion 2) as
  success criteria. Both ship: the placeholder seam removes the
  KNOWN-bad `null` argument at the root, and the catch-all capture is the
  defense in depth that guarantees "never uncaught escape into
  `runner-error`" for every other error class (a representative value the
  implementation rejects, an internal cast, a `StateError`).
- **Satisfied-with-rejection over a new verdict**: the issue offers
  `contract-argument-rejected` (a new verdict) OR satisfied-with-rejection.
  A new verdict would touch the verify-red classifier and the state
  machine — forbidden by the issue's own hard constraints — while
  satisfied-with-rejection falls out of the scaffold's EXISTING Case 2
  semantics (the outcome space is binary: `UnimplementedError` = the
  contract unsatisfied; anything else = the implementation is real). The
  template comments NAME the rejection so the author reads what happened
  (surfaced, not papered over).
- **`on Object`, not `on Error`**: implementations throw both `Error`s and
  `Exception`s (and pathological raw values). The catch-all arm uses
  `on Object` so the guarantee is total; `_captured` additionally records
  the thrown value in the emitted `_rejection` signal, and the Case 3
  guard keys on that SIGNAL — never the outcome's runtime type. A captured
  Error/Exception rejection skips the return-type assertion
  (satisfied-with-rejection); a thrown raw value — neither an `Error` nor
  an `Exception` — fails Case 3's Error/Exception assertion honestly
  (surfaced, never an escape, and never mistaken for a return that did
  not happen — PR #1558 review finding).
- **Placeholder for `dynamic`, literal `null` only for nullable complex
  types**: `_representativeArg` keeps `null` for `T?` complex types (the
  declared shape IS nullable — `null` is a legitimate representative) and
  for nothing else; `dynamic`/empty become placeholder seams. The empty-
  type case travels with `dynamic` (the parser never emits it today, but
  the resolver must not regress to `null` if it ever does).

## Risks / mitigations

- **Golden churn**: the #1513 fixture pins the default render byte for
  byte — regenerated in the same change (SC-5), and the regeneration is
  mechanical (writer output for the same fixture shape, no hand edits).
- **False green concern**: a validating implementation that rejects the
  scaffold argument now passes the contract test. This is the issue's own
  named outcome (satisfied-with-rejection): the contract lane proves the
  seam is IMPLEMENTED, the unit lane owns behavioral correctness, and the
  alternative (grading a rejection BLOCKED) would make
  argument-validating contracts unsatisfiable without hand-editing the
  scaffold — the exact complaint #1541 records.
- **Pin drift**: the #1007 fast-tier suite pins `Case 1 of 3` /
  `Case 2 of 3` / `Case 3 of 3`, `isNot(isA<UnimplementedError>())`,
  `isA<bool>()`, and the one-test-per-behavior shape for the scalar
  contract `User.validateEmail(String email) -> bool` — all preserved
  (the guard wraps Case 3's expect; the pin strings survive).

## Project Structure

### Documentation (this feature)

```text
specs/1541-contract-harness-declared-shape-args/
├── spec.md              # Feature specification (/speckit.specify)
├── plan.md              # This file (/speckit.plan)
├── checklists/
│   └── requirements.md  # Spec quality checklist
├── tasks.md             # /speckit.tasks output
└── tdd/
    ├── test-list.md     # /speckit.tdd.plan output
    └── verification.md  # /speckit.tdd.verify output
```

### Source Code (repository root)

```text
lib/src/plugins/tdd/services/
└── contract_test_writer.dart   # THE fix: _representativeArg, emitted
                                # _captured, Case 3 guard
test/fixtures/baseline_outputs/
└── bug_1513_contract_default_render.txt  # regenerated golden
test/plugins/tdd/services/
└── bug_1541_contract_harness_args_test.dart    # fast-tier render pins
test/plugins/tdd/commands/
└── contract_satisfied_with_rejection_e2e_1541_test.dart  # slow-tier e2e
```
