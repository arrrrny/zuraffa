# Research: `zuraffa_ocr` federated plugin delivery

**Feature**: specs/1602-zuraffa-ocr-plugin | **Date**: 2026-09-13

## D1 — The generator is frozen; this feature delivers an instance

- **Decision**: No changes to `PluginScaffold`, the command, or the
  templates. All work is: invocation (fixed arguments), verification
  tests, and the delivery procedure.
- **Rationale**: The generator's generic behaviors were proven in spec
  1601 (15 fast cases + slow e2e + 3/3 mutants). Re-verifying the
  generator would duplicate that suite; the OCR-specific risk is confined
  to the stamps (description, repo slug, topics, `Ocr` noun shapes) and
  the instance health board.

## D2 — Fast tier asserts the OCR instance contract through the real CLI

- **Decision**: `test/package_sdk/plugin_ocr_instance_test.dart` runs the
  REAL CLI (`run_zfa_source`, `package create-plugin zuraffa_ocr --repo
  arrrrrny/zuraffa_ocr --description <OCR description> --no-gate`) into a
  temp dir and asserts, offline: the five-package layout; verbatim
  description in every pubspec; repository/issue_tracker slugs; `ocr`
  topic; dependency invariants; per-package LICENSE/CHANGELOG and no
  `publish_to`; `Ocr`-shaped public names (`OcrPort`, `OcrService`,
  `AndroidOcr`/`IosOcr`/`MacosOcr` prefixes) in the app/adapter barrels;
  harness integrity (barrel import + test double).
- **Rationale**: The CLI path exercises the same engine the delivery
  uses; pure `dart test` + `package:yaml` keeps the tier offline-fast.
  Class-name assertions pin the `zuraffa_`-prefix strip (`Ocr`, not
  `ZuraffaOcr`) — the one name shape not covered by spec 1601's tests.

## D3 — Slow tier proves the family board for the OCR shape

- **Decision**: `test/package_sdk/plugin_ocr_e2e_test.dart`
  (`integration`,`slow`) scaffolds into a temp dir, then per package:
  `dart pub get` → `dart analyze --no-fatal-warnings` → `dart test` →
  `dart pub publish --dry-run`, all exit 0.
- **Rationale**: Spec 1601's e2e proved scaffold→board for a neutral
  name; OCR adds the `Ocr` class prefixes and a longer description —
  compile-level risk is tiny but the board is the FR-004/FR-005 contract,
  and the delivery board (D4) should be reproducible from a test.

## D4 — Delivery procedure mirrors the zuraffa_ffi run

- **Decision**: Scaffold into `~/Developer/zuraffa_ocr` (same CLI
  arguments; refuses if the dir exists), run the family gates locally,
  `git init -b master` + initial commit, `gh repo create --public
  --source . --push`, verify `gh repo view` + HTTP 200. Publishing to
  pub.dev is explicitly out of scope (dry-run-clean only), per spec
  Assumptions.
- **Rationale**: Identical to the accepted #678 delivery; keeps this
  feature's scope to "create a new repo" as requested.

## D5 — Fixed inputs (from the spec, no clarification needed)

- name: `zuraffa_ocr` | platforms: default (android, ios, macos)
- description: "Typed OCR support for the Zuraffa ecosystem: a pure-Dart
  port, recognition lifecycle, and typed failures behind an injected
  platform channel with federated adapters."
- repo slug: `arrrrny/zuraffa_ocr` | version 0.1.0 | zuraffa `^6.2.2`
