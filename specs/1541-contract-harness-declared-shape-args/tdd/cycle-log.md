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


## Cycle C2 — PR #1558 review fixes (renderable-shape literals + rejection signal)

- **BASELINE** (review findings on 694f629f, both reproduced through the
  real writer before the fix):
  - Finding 1 (major, inline comment 3999249815): `_representativeArg` fell
    through to the `_argN()` placeholder for declared types the seam
    renders verbatim (`List<T>`, `Set<T>`, `Map<K, V>`, `Iterable<T>`,
    `Future<T>`, `Stream<T>`); the placeholder's `Object?` return does not
    compile against those declared parameter types, so `zfa tdd gen`
    emitted a pair that failed to LOAD (`The argument type 'Object?' can't
    be assigned to the parameter type 'List<String>'`) — verify-red could
    only grade a load/runner error, never the named BLOCKED verdict.
  - Finding 2 (minor, inline comment 3999249824): the Case 3 guard
    (`outcome is! Error && outcome is! Exception`) guessed "was thrown"
    from the runtime type; a seam throwing a raw value MATCHING the
    declared return type (`String label(String name) => throw 'not
    implemented yet';`) passed the contract test (exit 0, no return value
    ever produced).
- **RED** (review-fix pins against the pre-fix writer — the writer edits
  stashed, the new pins live):
  - `dart test test/plugins/tdd/services/bug_1541_contract_harness_args_test.dart`
    → **10 pass / 8 red**: the U-1541-3 signal pin, 5 of the 6 U-1541-8
    shape pins (the non-renderable-inner guard held by construction), and
    both U-1541-9 pins; the 10 original #1541 pins stayed green.
- **GREEN** (post-fix):
  - `dart test test/plugins/tdd/services/bug_1541_contract_harness_args_test.dart`
    → **18/18**.
  - Combined changed-file loop (bug_1513 + bug_1541 + contract_kind_1007 +
    bug_1363 + bug_1443 + the dogfooded test/tdd/004-login-ui pair) →
    **50/50** — the #1513 golden (regenerated again for the rejection
    signal + guarded Case 3) byte-compares; the scalar `impl(0, 0)` render
    survives.
  - Slow-tier e2e (`dart test --preset=all
    test/plugins/tdd/commands/contract_satisfied_with_rejection_e2e_1541_test.dart`,
    real `dart test` subprocesses) → **5/5**: the three original outcomes
    plus U-1541-8 (a real `List<String>` pair LOADS, blocks at the Case 2
    assertion, and satisfies with an implementation) and U-1541-9 (a
    raw-throwing seam fails Case 3 with the named `threw a raw value`
    assertion).
  - Generated-scaffold analyzer check (scratch package, every new shape +
    the two-case render): `dart analyze .` → **No issues found!** — the
    rejection signal is emitted with its Case 3 reader, so two-case
    scaffolds carry no unread declaration.
  - Wider fast-tier chunks: `test/plugins/tdd/services` **952 pass + 1
    skip**; `test/plugins/tdd/commands` **532 pass** + the pre-existing
    macOS `view_command_test` U-V3 failure (issue #1463 — reproduced on
    the unmodified base with the changes stashed; unrelated); `test/tdd`
    157 pass.
  - Analyzer parity: `dart analyze lib test bin` → **112 issues; the issue
    SET byte-identical** to the pre-change baseline (issue lists diffed
    clean with the changes stashed).
  - Artifacts: the test list closes U-1541-1..9 as GREEN (rows 8/9 added),
    the plan's Case-3/raw-value rationale is aligned with the
    signal-based semantics, and the verification table carries the new
    behaviors.
