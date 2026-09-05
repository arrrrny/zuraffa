# Plan — spec 0996-receipts-standalone-capabilities

## Approach

Close the receipt gap identified in issue #996: `ReceiptStore` is written
only by `PluginManager._persistGenerationReceipt` on the `zfa make` path;
standalone capability invocations write nothing. The fix is a thin
execution wrapper (`CapabilityInvocationWrapper`) that every standalone
invocation flows through, persisting a `proof.v1` receipt after each
successful execution.

## Architecture

1. **`CapabilityInvocationWrapper`** (new,
   `lib/src/core/plugin_system/capability_invocation_wrapper.dart`) —
   wraps `capability.execute(args)`; on success builds and persists the
   receipt (best-effort, mirroring the make-path contract). Public
   `persistReceipt` so non-capability standalone paths
   (`zfa shadcn <layout>`) can ship the same proof.
2. **`GenerationReceipt` extension** (`receipt_store.dart`) — optional
   `plugin`, `capability`, `entity`, `methodset`, `runHash` (`hash`) and
   `receiptVersion` fields; `ReceiptStore.saveCapability` persists keyed
   `<plugin>-<capability>-<entity>-<timestamp>.json`.
3. **Hook sites** — `CapabilityCommand.run()` executes through the
   wrapper (pluginId injected by `PluginCommand`, falling back to the
   parent command name); `ShadcnCommand.run()` persists post-generation
   (capability = layout).
4. **`ProofReport.valid`** (`proof_checker.dart`) — the machine verdict
   speaks `valid` alongside `ok` (issue #996 wording).
5. **`ReceiptPreflight`** (new,
   `lib/src/plugins/tdd/services/receipt_preflight.dart`) — the
   `zfa tdd verify` preflight gate: every shipped receipt must validate,
   and receipt-shipping projects must cover every audited subject
   (missing receipt → gate failure, exit 1, no audit). No receipts →
   vacuous pass (backward compatible).

## Constraints honored

- Receipts machine-readable: `{plugin, capability, entity, hash,
  methodset, files, receipt_version: 1}` (asserted on the raw stored
  JSON).
- Best-effort persistence — a receipt failure never fails a successful
  generation.
- One PR; existing make/entity receipt behavior unchanged (regression
  tests green).

## Discovered during implementation

`zfa shadcn <layout> <Entity>` was broken on master before any receipt
concern: `PluginManager.buildContext` reads `--dry-run`, `--layout`,
`--methods`, ... off `argResults`, options ShadcnCommand never
registered — the invocation died with "Could not find an option named
--dry-run". Fixed by registering the core params (mirrors
`MakeCommand._addCoreOptions`); required for FR-002's shadcn row.

Two existing tests that drive real generation through `CapabilityCommand`
without pinning a project root (`test/plugins/mock/create_mock_capability_test.dart`,
`test/integration/di_flag_parsing_test.dart`) now pin it — the new
receipt side effect must not pollute the repo working tree.
