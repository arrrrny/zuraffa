# TDD Cycle Log — Spec 1602 (append-only)

## Baseline (pre-loop)

- Feature: specs/1602-zuraffa-ocr-plugin (issue #684, epic #214).
- Suite state before any behavior work: `dart test test/package_sdk/` →
  **58 passing, 0 failing** on branch `1602-zuraffa-ocr-plugin`
  (master + spec-1602 artifacts). Working tree clean.
- Test list: 4 behaviors (B1–B4). B1/B2/B3 are instance-verification
  behaviors (red = the missing test file's behaviors are unwritten);
  B4 is the delivery procedure (red = repo absent). The generator is
  frozen; failures against it are roadblocks, not fix prompts.
- Derivation: LLM-guided fallback (repo not `.zfa.json`-wired), same as
  specs 1600/1601.

## Cycle C1 — the OCR instance contract (B1, B2)

- **RED** (initial run of the new instance test, recorded before any
  change): 0/4 passed. Two distinct causes, honestly separated:
  1. Harness timeouts (60s test ceiling; helper's first AOT/source spawn
     75s+) — fixed test-side: single shared scaffold in `setUpAll`,
     file-level 6-minute timeout, explicit 240s child budget for the
     scaffold spawn.
  2. **Generator roadblock (the real finding)**: the scaffold stamped
     `zuraffa: ^6.2.3` from the dev `version.dart` while pub.dev's latest
     is **6.2.2** — an unresolvable hosted constraint. Every generated
     package would fail `dart pub get` for anyone without a local
     checkout. This is issue #1615; the maintainer had already written
     the fix (fac74541 on `fix/1615-scaffold-published-zuraffa-constraint`,
     resolving the constraint from pub.dev with a `--zuraffa-constraint`
     override and a version-const fallback) — adopted into this branch by
     merge rather than improvised.
- **GREEN**: after the merge, `dart test test/package_sdk/
  plugin_ocr_instance_test.dart` → `+4: All tests passed!` (B1, B2, B2b,
  B2c). Full scoped suite: `+65: All tests passed!` (58 baseline + 4 OCR
  + 3 maintainer B12 tests).
