# Tasks: 1128 — provider A+ upgrade (`--explain` + comprehensive error handling)

Dependency-ordered, MVP-first. Behaviors come before non-behavioral
wiring. Each behavior task is annotated with its failing-first test (the
TDD cycle: red → green → refactor) — see `tdd/test-list.md` for the
behavior-to-test traceability matrix.

- [ ] T1: RED — read spec + plan; capture the precise `--explain`
      output shape (no implementation yet). Write the failing
      `--explain` tests under
      `test/plugins/provider/provider_verify_test.dart` (failing case,
      clean case, `--explain --json` dominance). Tests FAIL because the
      `--explain` flag does not exist yet (CommandRunner raises
      `UnrecognizedFlagException` or argparse-equivalent).
- [ ] T2: RED — write the failing error-handling test under
      `test/plugins/provider/create_provider_capability_test.dart`:
      missing-service-interface path asserts `result.success, isFalse`
      (currently throws — the test fails on the assertion that no
      exception propagates). Also MIGRATE the existing
      `throwsA(isA<StateError>())` test to the new
      `ExecutionResult(success:false)` contract — that migration is
      itself a red→green transition for the new contract.
- [ ] T3: GREEN — implement `--explain` in
      `lib/src/commands/provider_verify_command.dart`:
      - register the flag via `argParser.addFlag('explain', negatable:
        false, help: 'Emit a human-readable explanation block.')`;
      - add `_printExplain(ProviderVerifyReport)` printing: a
        `Provider Verify — Explain` header line, the entity, the
        resolved interface, the provider file, the registered methods
        (one per line, indented), the verdict line (`✅ verified` or
        `❌ not verified — N finding(s)`), and per-finding
        `--> fix:` hints when present;
      - in `run()`, branch: `if (json) → jsonEncode; else if (explain)
        → _printExplain; else → _printText`. Exit code unchanged
        (`report.ok ? 0 : 1`).
      Run T1 tests → expect green.
- [ ] T4: GREEN — wrap `execute()` in `CreateProviderCapability` in
      try/catch matching `CreateDiCapability.execute` (lines 125-142
      of `create_di_capability.dart`): catch any exception from
      `_generateFiles`, return `ExecutionResult(success: false,
      message: 'provider create failed for $name: $e', data:
      {'generatedFiles': const <GeneratedFile>[]})`. The `_emitReceipt`
      helper stays as-is (already best-effort). Run T2 tests → expect
      green.
- [ ] T5: REFACTOR — re-read both diffs; ensure no duplication, no
      dead branches, names match sibling capabilities (`di`/`repository`).
- [ ] T6: VERIFY — `dart analyze` on the two changed `lib/` files;
      `dart test` on the two changed `test/` files (cloud-agent
      discipline — never the full suite); record ACTUAL pass/fail counts.
      `dart format .` → `git diff --stat` MUST show zero formatting
      diffs.
- [ ] T7: TDD.VERIFY — write `tdd/verification.md` citing the actual
      test runs (not what should pass — what DID pass), the red
      evidence captured in `cycle-log.md`, and the
      acceptance-criteria → test traceability.
- [ ] T8: COMMIT + PR — Conventional Commits subject
      `feat(1128): provider plugin — --explain output, comprehensive
      error handling (B+ → A+ upgrade)`, body links to spec 1128,
      includes explain output demo + error-handling proof. Push to
      `arrrrny/zuraffa` `spec/1128-provider-explain-error-handling`,
      open PR against `master`. Closes #1128.

## Dependency order

```
T1 (red explain) ─┐
                  ├─→ T3 (green explain) ─┐
                  │                       ├─→ T5 (refactor) ─→ T6 (verify) ─→ T7 (verification.md) ─→ T8 (commit + PR)
T2 (red error)  ──┴─→ T4 (green error) ──┘
```

T1 and T2 are independent red phases (parallel-safe). T3 and T4 are
independent green phases (parallel-safe). T5+ are sequential gates.
