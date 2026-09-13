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
