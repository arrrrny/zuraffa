# Analyze: 1126-state-verify-receipts-explain — cross-artifact check

Run before TDD. Checked spec.md ↔ plan.md ↔ tasks.md ↔ tdd/test-list.md
against each other and the codebase.

1. **Receipt path consistency** — spec.md SC-2/constraints and the issue
   pin `.zfa/receipts/state-<entity>.json`. plan.md decision 1 resolves
   `<entity>` to snake_case (`state-product.json`), mirroring
   `datasource-<entity>.json` (spec #977, same `saveNamed` contract).
   tasks.md T3 and the tests use the same derivation
   (`StateReceiptWriter.receiptFileName`). No drift.
2. **Timestamp deviation recorded once, used everywhere** — spec.md
   Constraints records the header-determinism deviation (version in
   header; timestamp in receipt `at`); plan.md decision 7 and T1/T2
   implement exactly that; the test list carries the determinism gate.
   Consistent.
3. **Envelope compatibility (SC-6)** — the existing envelope asserts in
   `state_create_json_receipt_test.dart` (SC-2a) check `command`,
   `verdict`, `exit_class`, `subject`, `artifacts`, `details`; none pin
   `receipts` contents. Adding the stable receipt path to `receipts` is
   additive; SC-2b filters by the `state-create-Product-` prefix, which
   `state-product.json` does not match (`.single` stays valid).
   `zfa proof check` (SC-2c/2d) loads both documents — identical
   digests, latest-wins — still green.
4. **Subcommand registration collision (#761)** — adding `verify` to
   `StateCommand.manualSubcommandNames` mirrors SPEC 1127's
   `ServiceCommand` (`{'create','verify'}`); no generic
   CapabilityCommand auto-registers a `verify` for state
   (`CreateStateCapability.name == 'create'` only). No collision.
5. **Config vocabulary = actual inputs** — schema keys
   `methods`/`no-entity`/`domain` are exactly the
   `context.data` keys `StatePlugin.generateWithContext` reads;
   `buildContext` merges them from argResults via configSchema
   properties (make-path flags become live). `--no-entity` maps to
   `GeneratorConfig.noEntity` (a `no-entity` CLI spelling is the
   schema key; the command option uses the same spelling).
6. **Analyzer availability** — `package:analyzer` is a transitive dep
   already used by `DatasourceExplainer`/`ProviderVerifier`; parsing
   the state file with `parseString(throwIfDiagnostics: false)` is the
   established defensive pattern.
7. **Disk discipline** — targeted suites only; kernel cache cleanup
   pre/post (standing obligation). No new fixtures beyond temp
   workspaces that the tests clean up.
8. **Spec-kit numbering** — next free slot: no `specs/1126-*` existed;
   `.specify/` untouched (templates/scripts pre-exist; extension `tdd`
   already installed → no re-init).

No cross-artifact drift found. Proceeding to tdd.run (red-green loop).
