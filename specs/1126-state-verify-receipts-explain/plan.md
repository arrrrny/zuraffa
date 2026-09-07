# Plan: 1126-state-verify-receipts-explain

## Technical Context

- **Feature**: state plugin verify gate, per-entity receipts,
  `--explain`, config schema, provenance headers (C+ → A+).
- **Language/Dart SDK**: Dart ^3.11 (repo constraint); toolchain used:
  Dart 3.13.3 stable. No Flutter dependency in the touched code paths
  (pure-Dart CLI + analyzer).
- **Existing surfaces touched**:
  - `lib/src/plugins/state/state_plugin.dart` — empty `configSchema`,
    `generateWithContext` reads `context.data['methods' | 'no-entity' |
    'domain']` (the vocabulary to declare).
  - `lib/src/plugins/state/capabilities/create_state_capability.dart` —
    unguarded `execute()`, no receipts.
  - `lib/src/commands/state_create_command.dart` — `--json` canonical
    envelope (SPEC 1105) + timestamped receipt (issue #1138) to
    preserve byte-for-byte.
  - `lib/src/commands/state_command.dart` — `manualSubcommandNames`
    gatekeeping first-party subcommands.
  - `lib/src/plugins/state/builders/state_builder.dart` — both emission
    branches (custom/orchestrator + entity) converge on
    `FileUtils.writeFile(filePath, content, 'state', …)`; the header
    stamps at the two `content` construction sites.
- **Provenance envelopes in-tree (the "same shape cache/route/tdd
  use")**: `GenerationReceipt` (`proof.v1`, schema + files[]
  sha256/bytes/snapshot + `hash` run digest + `receipt_version`),
  written through `ReceiptStore.saveNamed` for stable per-entity
  names (`datasource-<entity>.json` precedent) or `saveCapability`
  for timestamped run receipts.

## Blueprint (proven in-tree patterns)

| Order | Pattern source | What is cloned |
|---|---|---|
| verify gate | SPEC 1127 `ServiceVerifyCommand` + spec #1131 `DatasourceVerifier` receipt-then-flags resolution | first-party `verify` subcommand on `StateCommand.manualSubcommandNames = {'create','verify'}`, `--json` canonical envelope, exit 0/1/2 |
| entity source hash | spec #1131 order 2 `DatasourceReceiptWriter._entitySourceBinding` | `entity_source: {path, sha256, bytes}` extra on the stable receipt |
| per-entity receipt | spec #1131 `DatasourceReceiptWriter` / SPEC 1127 `ServiceReceiptWriter` | `StateReceiptWriter` → `ReceiptStore.saveNamed('state-<entity>.json', …)` with `state_sha256`, `state_class`, `methods` extras |
| capability receipts + guard | SPEC 1127 `CreateServiceCapability.execute()` | try/catch guard (`success: false`, never an uncaught crash), best-effort `_emitReceipt`, `data['stateReceipt']` |
| `--explain` | SPEC 1127 `ServiceCreateCommand._explain` + spec #1131 `DatasourceExplainer` | describe-without-generate; prose block + envelope `explain` block (issue #1122 field) |
| config schema gate | issue #1122 `validateRouteConfig` + `routeConfigSchema` | filled `configSchema` + `validateStateConfig` refusing unknown keys / wrong types / empty schema |
| provenance header | spec #1131 order 5 `DatasourceProvenance` + spec #979 `ProviderBuilder.generatedHeader` | `StateProvenance.headerFor(entity)` stamped in both StateBuilder emission branches |

## Design decisions

1. **Receipt naming**: `state-<snake-entity>.json`
   (`ReceiptStore.saveNamed`), snake_case like the datasource ledger —
   the state artifact itself is snake (`product_state.dart`). The
   verify gate and machine readers resolve it deterministically via
   `StateReceiptWriter.receiptFileName/receiptPath/load`.
2. **Two receipts per CLI run, additive**: the CLI keeps its
   timestamped #1138 receipt (`saveCapability`, full capability
   provenance) AND gains the stable per-entity document. The envelope
   `receipts` list grows additively (SC-6: existing assertions
   unchanged; spec-976 SC-2b filters on the `state-create-` prefix and
   is unaffected).
3. **Verify semantics** (receipt-driven, flags never required):
   - contract = stable receipt (`methods`, `state_sha256`,
     `entity_source`, `files[0]`);
   - artifact freshness: sha256(final bytes) vs `state_sha256` →
     `modified` finding on mismatch (stale state, e.g. hand-edited or
     partially regenerated);
   - entity freshness: sha256(entity file) vs `entity_source.sha256` →
     `stale_entity` finding (entity changed, state not regenerated);
   - member conformance: every contract method must surface its
     derived `is<Continuous>` member in the parsed state class →
     `missing_method` finding;
   - clean = receipt exists ∧ file exists ∧ no findings.
4. **AST parsing**: `package:analyzer` `parseString` (throwIfDiagnostics:
   false) — a malformed state file is a finding (`parse_error`), never
   a crash (the #1131 order-4 convention).
5. **Explain is a sibling of generate, never a mode of it**:
   `--explain` short-circuits before `plugin.generate`, prints the
   plan, exit 0 (verdict `skip` under `--json`). Derivation mapping is
   the single source of truth `StringUtils.toContinuous` — the same
   function `_boolFieldsForMethods` feeds, so explain cannot drift
   from emission.
6. **Config gate wiring**: `validateStateConfig` (public, in
   `state_plugin.dart`) is wired into (a) `StateCreateCommand` —
   validates the resolved `{methods, no-entity, domain}` before
   generating (usage refusal + `--> fix:`), and (b)
   `CreateStateCapability.execute()` — JSON args are the real
   unknown-key surface (no args-package type enforcement), refused
   with `success: false`.
7. **Provenance header determinism** (deviation recorded in spec.md):
   marker + version + regeneration hint, no run timestamp — run-varying
   bytes would permanently break `state_snapshot_test` and
   `state_make_drift_test`; timestamp provenance lives in the receipt
   `at`. Goldens are regenerated ONCE with the header
   (ZFA_STATE_UPDATE_GOLDENS=1) and stay byte-stable afterwards.
8. **Make-path consistency**: the header stamps inside
   `StateBuilder.generate`, so `zfa make --state` and `zfa state
   create` stay byte-identical (the drift gate's core invariant).

## Tasks / dependencies (MVP-first, dependency-ordered)

1. `StateReceiptWriter` (state_receipt.dart) — no deps; needed by
   orders 1+2. + tests.
2. Provenance header (`StateProvenance` + StateBuilder stamping +
   golden regen). + tests.
3. Config schema fill + `validateStateConfig` + command/capability
   wiring. + tests.
4. Capability: guarded execute + `_emitReceipt` (depends on 1). + tests.
5. `StateCreateCommand`: stable receipt emission (depends on 1) +
   `--explain` (SC-3) + `--domain`/`--no-entity` knobs (SC-4 grammar).
   + tests.
6. `StateVerifier` + `StateVerifyCommand` + `StateCommand` wiring
   (depends on 1). + tests.
7. Analyze/format/targeted suites; spec artifacts committed.

## Verification strategy

- Targeted suites only (disk discipline): the new test files plus the
  pre-existing suites that own the touched files
  (`state_create_json_receipt_test`, `state_snapshot_test`,
  `state_make_drift_test`, `state_output_schema_test`,
  capability receipt hook tests).
- `dart analyze` on changed files; `dart format .` with zero residual
  diff (CI format gate).
- Red-first evidence recorded per behavior in tdd/test-list.md and
  tdd/cycle-log.md; mutation checks for the verify gate (flip the
  digest comparison → the drift test must go red).
