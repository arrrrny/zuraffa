# Quickstart: skin-contract.v1 (issue #1164)

## Unit-level validation (this repo)

```bash
dart test test/plugins/skin_contract/     # parser + round-trip + repo-wide schema test
dart test test/plugins/tdd/plan_skin_contract_test.dart   # emitter behavioral tests
dart analyze lib/src/skin/contract lib/src/plugins/tdd/commands/plan_command.dart
```

Expected: all green, analyzer clean.

## Emitter end-to-end

```bash
zfa tdd plan 006-login-skin        # (or any spec carrying `## Skin Contract:`)
ls specs/006-login-skin/tdd/04-skin-contract.schema.json
```

Expected: the schema file exists, is valid JSON Schema, and every model field appears in it.

## Repo-wide guarantee

```bash
dart test test/plugins/skin_contract/schema_test.dart
```

Expected: every contract-bearing spec in `specs/` is discovered, parsed, and validated —
or the failure names the spec and key.
