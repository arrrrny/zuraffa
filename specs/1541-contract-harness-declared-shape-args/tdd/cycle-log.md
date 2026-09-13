# TDD Cycle Log — Spec 1541 (append-only)

## Cycle C1 — the contract harness invokes declared-shape args + `_captured` catches all errors

- **BASELINE** (recorded before the fix):
  - Pre-change `dart analyze` = 112 pre-existing issues (all infos; saved
    at `/home/z/my-project/baseline_analyze.txt`, outside the repo tree).
  - Root cause reproduced by reading the render pipeline:
    `contract_test_writer.dart` `_representativeArg` maps `dynamic`/empty
    to the literal `null`, and the emitted `_captured` catches ONLY
    `UnimplementedError` — an argument-validating seam throws
    `ArgumentError`/`TypeError` uncaught, the transcript segment carries no
    `Expected:`/`Actual:` signature, and verify-red's
    `_classifyBatchBehavior` grades `runner-error` (never a named verdict).
- **RED** (pre-fix, recorded before the fix commit):
  - `dart test test/plugins/tdd/services/bug_1541_contract_harness_args_test.dart`
    → **5 red / 5 green** (the honest pre-fix state):
    - RED `U-1541-1 ... the Case 2 invocation passes _arg0(), never the
      literal null` — the render contains `impl(null)` (the #1541 defect,
      reproduced at the render surface).
    - RED `U-1541-1 ... the placeholder helper instructs the author` — no
      `Object? _arg0() =>` seam, no `provide a representative` instruction
      for the dynamic param.
    - RED `U-1541-2 ... every parseable render emits the catch-all capture
      arm` — the emitted `_captured` has only `on UnimplementedError`.
    - RED `U-1541-2 ... the captured-error doc names the outcome split` —
      no `issue #1541` split documentation.
    - RED `U-1541-3 ... Case 3 runs only when the captured outcome is not
      a rejection` — the return-type assertion is unguarded.
    - GREEN (the pins that must survive): nullable complex type keeps
      `impl(null)`; scalar literal keeps `impl('contract-sample')`; the
      #1007 enumeration + `isNot(isA<UnimplementedError>())` pins; the
      non-scalar two-case shape; the #1513 import surface.
- **GREEN** (post-fix):
  - `dart test test/plugins/tdd/services/bug_1541_contract_harness_args_test.dart`
    → **10/10 pass** — every RED pin flipped; the surviving pins held.
  - `dart test test/plugins/tdd/services/bug_1513_contract_lane_flutter_imports_test.dart
    test/plugins/tdd/commands/contract_kind_1007_test.dart
    test/plugins/tdd/services/bug_1443_void_contract_seam_test.dart
    test/plugins/tdd/bug_1363_contract_stub_dup_args_test.dart
    test/tdd/004-login-ui/contract_a1_test.dart` → **42/42 pass** — the
    #1513 byte-comparison golden pin passes against the REGENERATED
    fixture; the #1007 fast-tier suite, the #1443 void-seam pins, the
    #1363 stub-arg pins and the dogfooded contract test are untouched.
  - Slow-tier e2e (`dart test --preset=all
    test/plugins/tdd/commands/contract_satisfied_with_rejection_e2e_1541_test.dart`,
    real `dart test` subprocesses) → **3/3 pass**:
    - U-1541-4: the argument-validating seam (throws `ArgumentError` for
      the scaffold's representative argument) runs the generated contract
      test to a PASS (exit 0) and verify-red grades
      `classification=unexpected-green` — satisfied-with-rejection, no
      seam shim, no hand-edited scaffold.
    - U-1541-5: the unimplemented seam STILL grades
      `classification=blocked certified=false` with the
      `contract-blocked.A1.json` receipt (FR-3 byte-unchanged).
    - U-1541-1 e2e: the ISSUE'S scenario — a `dynamic` param seam that
      casts (`subsystem as String`) — the scaffold passes `_arg0()` (the
      failure is the named `provide a representative `dynamic``
      assertion, and `type 'Null' is not a subtype` is UNREACHABLE);
      replacing the placeholder with a representative value satisfies
      the contract against the validating seam.
  - Wider fast-tier chunks (all green): test/plugins/tdd/commands 533,
    test/plugins/tdd/services 945, test/tdd 157, test/plugins/mock 157,
    test/commands 370.


