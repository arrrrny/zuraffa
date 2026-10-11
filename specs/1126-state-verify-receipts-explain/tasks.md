# Tasks: 1126-state-verify-receipts-explain

Dependency-ordered, MVP-first. Every behavior task carries a failing
test BEFORE its implementation lands (tdd/test-list.md is the trace).

## Phase A — Provenance foundation (no behavior change to surfaces)

- [ ] T1. `lib/src/plugins/state/state_provenance.dart`:
      `StateProvenance.generatedHeader` +
      `StateProvenance.headerFor(entityName)` (marker + generator
      version + regeneration hint; deterministic — no run timestamp).
- [ ] T2. Stamp the header in BOTH `StateBuilder.generate` emission
      branches (custom/orchestrator + entity) before
      `FileUtils.writeFile`; regenerate the snapshot goldens once
      (ZFA_STATE_UPDATE_GOLDENS=1). Test: state_provenance_test.dart.

## Phase B — Receipts (order 2, MVP)

- [ ] T3. `lib/src/plugins/state/state_receipt.dart`:
      `StateReceiptWriter.write/load` + `receiptFileName/receiptPath`
      → `.zfa/receipts/state-<snake>.json` via
      `ReceiptStore.saveNamed`; extras: `state_sha256`, `entity_source`
      `{path,sha256,bytes}` (null on no-entity), `state_class`,
      `methods`. Test: state_capability_receipt_test.dart.
- [ ] T4. `CreateStateCapability.execute()`: guard the generation path
      (try/catch → `success: false` + message), best-effort receipt on
      real (non-dry) runs, `data['stateReceipt']`; injectable
      `projectRoot`. Test: state_capability_receipt_test.dart.
- [ ] T5. `StateCreateCommand._emitReceipt`: also write the stable
      per-entity receipt; envelope `receipts` lists both paths
      (additive). Test: state_capability_receipt_test.dart (CLI leg).

## Phase C — Config schema (order 4)

- [ ] T6. Fill `StatePlugin.configSchema`: `methods` (array of string,
      default get/update), `no-entity` (boolean, default false),
      `domain` (string) — matching `generateWithContext` inputs.
- [ ] T7. `validateStateConfig` in state_plugin.dart (route/#1122
      clone): unknown keys, boolean/string/array type mismatches,
      empty-schema refusal. Test: state_config_schema_test.dart.
- [ ] T8. Wire the gate: `StateCreateCommand` validates the resolved
      config (usage refusal + `--> fix:`); capability refuses a
      malformed JSON config (`success: false`).
- [ ] T9. Grammar knobs on the CLI: `--domain` and `--no-entity`
      options on `StateCreateCommand` (the schema vocabulary becomes
      reachable; `GeneratorConfig` already consumes them).

## Phase D — Explain (order 3)

- [ ] T10. `--explain` flag on `StateCreateCommand`; short-circuit
      before generation; prose block: state class, output file, mode,
      generated state members, derivation mapping
      (method → is<Continuous> via `StringUtils.toContinuous`),
      receipt path. `--json` → envelope verdict `skip` with the
      `explain` block. Test: state_explain_test.dart.

## Phase E — Verify gate (order 1, depends on B)

- [ ] T11. `lib/src/plugins/state/state_verifier.dart`:
      `StateVerifier.verify()` → receipt load, file resolution
      (receipt path → conventional), artifact digest check, entity
      freshness check, per-method member conformance (analyzer
      parseString, defensive); `StateVerifyReport` with
      methodsMatched/methodsMissing/stale/findings + `toJson`.
      Test: state_verify_gate_test.dart.
- [ ] T12. `lib/src/commands/state_verify_command.dart`:
      `zfa state verify <Entity> [--json]` — exit 0 clean, exit 1
      drift (every finding ends with `--> fix:`), exit 2 usage;
      `--json` → one canonical `zuraffa.verdict.v1` envelope.
- [ ] T13. `StateCommand`: register `StateVerifyCommand`,
      `manualSubcommandNames` → `{'create', 'verify'}`.

## Phase F — Hygiene + artifacts

- [ ] T14. `dart analyze` changed files, `dart format .` (zero
      residual diff), targeted suites green; kernel cache cleanup.
- [ ] T15. tdd/verification.md (test-first + mutation evidence);
      commit spec-kit artifacts with the code.
