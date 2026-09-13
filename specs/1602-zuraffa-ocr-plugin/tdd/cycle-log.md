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

## Cycle C2 — the family board (B3)

- **First run: `11:56 +1: All tests passed!`** — born-green (GUARD, honest
  classification): the identical board was proven for the generator by the
  zuraffa_ffi delivery and spec-1601's e2e; the OCR delta is the stamped
  names/description, already pinned by B1/B2. Unlike the 1601 e2e, B3
  passes NO `--zuraffa-path`, so the hosted constraint resolves against
  pub.dev — the exact miss #1615 fixed. Board: 5 packages × (pub get,
  analyze, test, publish --dry-run) all exit 0, elapsed 10m16s (budget
  15 min).

## Cycle C3 — delivery (B4)

- Contract invocation run in `~/Developer`: `zfa package create-plugin
  zuraffa_ocr --repo arrrrrny/zuraffa_ocr --description "Typed OCR
  support …"` (default platforms, built-in gate). Gate: pub get + analyze
  OK on all five packages; generated pubspecs pin `zuraffa: ^6.2.2` (the
  PUBLISHED line, post-#1615).
- Board on the delivered repo: `dart test` + `dart pub publish
  --dry-run` per package → 5/5 OK (gate covered pub get + analyze).
- `git init -b master` → initial commit 61c72d4 (64 files, no local paths
  in committed manifests) → `gh repo create arrrrrny/zuraffa_ocr --public
  --source . --push` → repo resolves: HTTP 200, public.

## Audit mutant sampling

- **M1**: fixture repo slug mutated to `arrrrny/wrong_slug` → B1 red
  (`+0 -1`) — the stamps assertions detect identity drift. **killed**.
- Restoration: file restored from backup, full file re-run `+4: All
  tests passed!`. The generator engine itself was mutation-audited in
  spec 1601 (3/3 killed) and is frozen here.
