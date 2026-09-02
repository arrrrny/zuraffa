# Verification: Issue #773 — `sync enable` String→int TypeError

Cycle: SDD spec → RED → GREEN → verify (all runs this session, branch
`fix/773-sync-enable-int-typeerror`, base master `6921c730`, Dart 3.13.3).

## Evidence

| # | Check | Command | Result |
|---|-------|---------|--------|
| B1 | Crash reproduces (real CLI, scratch package) | `zfa sync enable --name Auth` | `❌ Error: type 'String' is not a subtype of type 'int'` (pre-fix) |
| B2 | Mechanism | code trace of `CapabilityCommand` | `addOption(defaultsTo: def?.toString())` → option default `'50'`; with-default option never null → `args['batchSize'] == '50'` (String) → `GeneratorConfig(syncBatchSize: '50')` |
| R1 | RED explicit flag | `dart test test/commands/capability_command_type_coercion_test.dart` | FAILED: `--batch-size 30` arrived as `'30'` (String) |
| R2 | RED schema defaults (#773 shape) | same run | FAILED: defaults arrived as `'50'`/`'5'` (Strings) |
| R3 | Guards (pre-fix) | same run | no-over-coercion + passthrough guards passed by design |
| G1 | GREEN unit | same file, post-fix | **4/4 pass** |
| G2 | GREEN real CLI | `zfa sync enable --name Auth` (scratch) | generates `auth_sync.dart`, `auth_sync_metadata_store.dart`, `auth_sync_strategy.dart`, `auth_sync_usecase.dart` — no TypeError |
| S1 | Regression | `dart test test/commands/ test/cli/ test/plugins/sync/` | **270/270 pass** |
| S2 | Static analysis | `dart analyze` (branch and pristine master) | No issues found |
| S3 | Format | `dart format` touched files | clean (0 changed after apply) |

## Fix summary

- `CapabilityCommand.run()`: single normalization pass over schema properties
  after arg assembly (JSON + flags + positional) — String values are coerced
  to the declared JSON-Schema type (`integer` → `int.tryParse`, `number` →
  `double.tryParse`, `boolean` → `'true'/'false'`). Unparseable input passes
  through unchanged (FR-4); string properties untouched (FR-3).
- Systemic by design: every capability declaring numeric properties benefits
  (sync `batchSize`/`maxRetries` proven; no per-capability patches needed).

## What was not audited

- Array element coercion (`items:` schema) — out of scope, no known path.
- Adding CLI-level validation errors for unparseable numerics (capability
  contracts unchanged; separate concern).
