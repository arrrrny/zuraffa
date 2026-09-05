# Tasks — spec 0996-receipts-standalone-capabilities

- [x] T001. RED then GREEN: `CapabilityInvocationWrapper` auto-persists a
      `proof.v1` receipt after every successful capability execution, keyed
      `<plugin>-<capability>-<entity>-<timestamp>.json`; hook in
      `CapabilityCommand.run()` (pluginId from `PluginCommand`).
      Evidence: `test/core/plugin_system/capability_invocation_wrapper_test.dart`,
      `test/commands/capability_command_receipt_hook_test.dart`
      (see `tdd/cycle-log.md`).
- [x] T002. GREEN: receipts emitted for all twelve listed capabilities —
      di create, cache adapter, repository create, usecase create,
      service create, datasource create, provider create, shadcn
      `<layout>`, state create, observer create, sync enable, strategy
      create. Evidence: `test/commands/capability_receipt_test.dart`
      (slow tier, `--preset=all`).
- [x] T003. GREEN: machine-readable receipt schema
      `{plugin, capability, entity, hash, methodset, files,
      receipt_version: 1}` — asserted on the raw stored JSON document;
      `hash` pinned to the canonical derivation.
- [x] T004. GREEN: `zfa proof check` on a standalone receipt validates —
      exit 0 with `valid: true` (`ProofReport.toJson` gains the `valid`
      verdict). Evidence: `test/core/proof/proof_check_valid_test.dart`
      (real CLI subprocess).
- [x] T005. GREEN: `zfa tdd verify` includes receipt-checking as a
      preflight gate; a missing receipt for an audited subject triggers
      gate failure (exit 1, mutation audit never starts); projects
      without receipts keep working. Evidence:
      `test/plugins/tdd/services/receipt_preflight_test.dart`.
- [x] T006. REFACTOR + VERIFY: `dart format .` (zero diffs),
      `dart analyze` (no new issues; all pre-existing errors live in
      `examples/`, which needs Flutter), chunked fast suite
      75/75 chunks green.
- [x] T007. `zfa tdd verify --feature 0996-receipts-standalone-capabilities`
      from the REAL run — `tdd/verification.md` committed from this
      session.
