# TDD Cycle Log — Spec 064 (append-only)

## Baseline (pre-loop)

- Feature: specs/064-migrate-html-to-markdown-ffi (issue #687, epic #214).
- In-repo suite (the loop's red/green scope): `dart test test/package_sdk/` →
  **58 passing, 0 failing** on branch `064-migrate-html-to-markdown-ffi`
  (= master + spec-064 artifacts). Working tree clean.
- Pre-migration package baseline (delivered repo `~/Developer/html_to_markdown_ffi`,
  clean clone at origin/master): `dart pub get` exit 0; `dart test` → **76 passing,
  0 failing** on the macOS host via the bundled macos dylibs; `dart analyze` → 0 errors,
  2 warnings, 65 infos (pre-existing: `avoid_print` in tests + deprecations). Post-migration
  gate per SC-001: zero errors + zero warnings (infos tolerated only at baseline parity in
  ported files).
- Test list: 6 behaviors (B1–B6). B1–B4 are test-first behaviors; B5/B6 are procedure
  behaviors (board + publish) evidenced in this log. The generator is frozen; failures
  against it are roadblocks, not fix prompts.
- Derivation: LLM-guided fallback (repo not `.zfa.json`-wired), same as specs 1600/1601/1602.

## Cycle C1 — RED baseline for the migration instance (B1–B4)

- **RED**: `dart test test/package_sdk/plugin_html_to_markdown_ffi_instance_test.dart`
  → `00:00 +0 -9: Some tests failed.` All 9 fail for the single honest reason:
  `~/Developer/html_to_markdown_ffi/packages/` does not exist — the migration is
  not delivered (B1a/B1b/B1c family assertions, B2a/B2b preserved-surface pins,
  B3a/B3b/B3c domain pins, B4 host-proof existence). No assertion was relaxed;
  the file pins the target state.
- Native parity constants recorded from the clean pre-migration clone:
  android 3×.so (2903004/4478336/4953808 B), ios 3×.a (32746784/32675128/32847136 B),
  macos 2×.dylib (3895968/4136208 B) — baked into the B1c pins.


## Cycle C2 — GREEN path, and a discovered-fact correction (B4 visitor pin)

- **Discovery (verified against the clean pre-migration worktree)**: the
  shipped `VisitorBridge` (1.1.0) is a documented stub — `attach()` is empty,
  "full NativeCallable bridge to the C VTable is in progress", visitors
  delegate to default conversion. The original B4 derivation ("skip/custom
  respected") over-reached the shipped behavior; probing that assumed
  skip-effect produced truncated-output false signals. The pin was corrected
  to parity: conversion with a visitor completes and renders identically to
  the default path (FR-003: binding logic preserved as shipped; no new vtable
  behavior invented during migration).
- Test list B4 wording updated accordingly (derivation artifact, not spec.md).
- App package suite: `dart test` → **90 passing, 0 failing** (76 ported legacy
  + service contract + host FFI proof) on the macOS host through the migrated
  stack.

## Cycle C3 — GREEN (B1–B4)

- `dart test test/package_sdk/plugin_html_to_markdown_ffi_instance_test.dart`
  → **+9: All tests passed!** (B1a family/stamps/binaries parity, B1b graph,
  B1c native artifact parity byte-for-byte, B2a preserved barrels, B2b ported
  suite presence, B3a/B3b/B3c generated domain, B4 host FFI proof spawn).
- B4 evidence: the spawned app-package run executes 90 tests against the real
  macos dylib through service → use case → repository → datasource (FR-004).
- Two instance-test pins were corrected during green (my derivation errors,
  not product issues): B1b app-package dep set (ffi/http/zorphy_annotation
  are legitimate hosted deps; invariant is "no in-family deps") and B1b
  adapter deps (scaffold adds zuraffa for GetIt; invariant is "contains
  app+core, never sibling adapters").
- Scoped suite: `dart test test/package_sdk/` → all green (58 baseline + 9
  instance).
