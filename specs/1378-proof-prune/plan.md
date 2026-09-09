# Plan — Spec 1378 proof prune

**Branch**: `1378-proof-prune` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

`ProofPruneCommand` in `proof_command.dart` (registered as a third proof
subcommand): classify every `ReceiptStore` record dead/partial/alive by
artifact existence under `Directory.current`; print per-receipt verdict
lines + a summary; delete the dead receipt files only under `--apply`.
Usage text gains the prune line.

## Test strategy

`test/commands/bug_1378_proof_prune_test.dart` — driven through a real
spawned zfa (the proof_command_test pattern, issue #506 cwd isolation):
B1 dry run lists + preserves, B2 --apply deletes dead + keeps live,
B3 partial kept, B4 empty store. Scoped pin: the four proof suites +
analyze.
