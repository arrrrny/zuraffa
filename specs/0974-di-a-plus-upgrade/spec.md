# SPEC 0974: di A+ upgrade — delete dead command, verify gate, standalone receipts, real success verdicts

- **Issue**: https://github.com/arrrrny/zuraffa/issues/974
- **Branch**: `spec/0974-di-a-plus-upgrade`
- **Grade target**: make `di` an A+ plugin (currently B+, 3.85/5)

## Why

The `di` plugin is the core of the simulation-DI story (#893/#914, merged) but
holds back on four counts: 427 LOC of dead code (`lib/src/commands/di_command.dart`,
zero importers), a hardcoded `success: true` verdict that lies to automation, no
receipts on the standalone `zfa di create|register` path (only `zfa make` ships
proof), and docs drift advertising the #856-killed positional grammar.

## Orders (from issue #974)

1. **Delete `lib/src/commands/di_command.dart`.** First verify zero importers
   with grep; if anything references it, rewire to `ModularDiCommand` instead.
   Delete, don't comment out.
2. **`zfa di verify`:** resolve every `getIt<T>()` call in generated
   registrations against classes on disk; dangling binding → exit 1 +
   `--> fix:` naming the class and expected file. This is the exact failure
   #284/#410 fixed by hand, made a gate.
3. **Receipts on the standalone path:** `zfa di create/register` append
   `.zfa/receipts/`-`di-<target>.json` (registrations written, index hash) via
   `ReceiptStore`.
4. **Real verdicts:** kill the hardcoded `success: true` —
   `ExecutionResult.success` reflects actual generation; warnings become
   structured `{target, reason}` entries.
5. **Fix docs:** openwiki DI section + `ModularDiCommand` option help — remove
   the dead positional grammar references.
6. **Tests:** di verify positive/negative (dangling binding must fail), receipt
   emission, structured warnings.

## Constraints

- Do not touch simulation-binding emission (spec 893) — it works and is
  behavior-tested.
- Failing-first tests under `test/plugins/di/`.
- One PR for the spec.

## Acceptance — all must hold

- `grep -r "di_command.dart"` returns nothing; fast suite green.
- `zfa di verify` catches a deliberately dangling `getIt<Missing>()`
  registration — tested.
- Standalone `di create` writes a receipt; `zfa proof check` green.
- A forced generation failure returns `success: false` — tested.

## References

- #893/#914 (simulation-DI story, merged), #284/#410 (dangling bindings fixed
  by hand), #856 (positional grammar killed), #807 (proof-carrying generation).
