# TDD Cycle Log — Spec 1541 (append-only)

## Cycle C1 — the contract harness invokes declared-shape args + `_captured` catches all errors

- **BASELINE** (recorded before the fix):
  - Pre-change `dart analyze` = 112 pre-existing issues (all infos; saved
    at `/home/z/my-project/baseline_analyze.txt`, outside the repo tree).
  - Root cause reproduced by reading the render pipeline:
    `contract_test_writer.dart` `_representativeArg` maps `dynamic`/empty
    to the literal `null`, and the emitted `_captured` catches ONLY
    `UnimplementedError` — an argument-validating seam throws
    `ArgumentError`/`TypeError` uncaught, the transcript segment carries no
    `Expected:`/`Actual:` signature, and verify-red's
    `_classifyBatchBehavior` grades `runner-error` (never a named verdict).
