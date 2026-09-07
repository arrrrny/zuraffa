# Tasks — spec 1119 usecase verify / explain / drift gate / certify

MVP first: the verify gate (T1–T5) is the core A+ deliverable; certify
(T6), explain (T7), drift (T8) and the capability split (T9) build on it.

- [x] T1 Extract `EntityUseCaseGenerator.buildUsecaseSource(config,
      method)` — in-memory source build shared by generation and the
      gate (pure refactor; `_generateForMethod` delegates).
- [x] T2 `UsecaseConformanceChecker.checkMethod` — per-method gate with
      findings (`missing_class`, `missing_method`, `signature_mismatch`,
      `parse_error`) each carrying a `--> fix:` line; expected shape
      derived via T1.
- [x] T3 `UsecaseConformanceChecker.describeMethod` — the explain
      contract reader (class, base class, variant, result type, params
      type, exception type) derived via T1.
- [x] T4 `UsecaseReceiptReader.load(projectRoot, entity)` — latest
      `usecase-create-<entity>-*.json` proof.v1 receipt.
- [x] T5 `UsecaseVerifyCommand` (`zfa usecase verify <Entity>`):
      receipt-then-flags method resolution, conventional file discovery
      fallback, `--> fix:` lines, canonical `--json` envelope, exit
      0/1/2; register in `UseCaseCommand` (manualSubcommandNames).
- [x] T6 `UseCaseCreateCommand --certify` — gate after generation;
      exit 1 + envelope `fail` when verification fails; certification
      outcome recorded in the receipt input.
- [x] T7 `UseCaseCreateCommand --explain` — human block (non-json) /
      envelope `explain` key (json, issue #1122 pattern).
- [x] T8 `UsecaseDriftChecker` — entity source sha256 vs receipt
      `spec.sha256`; `entity_drift` finding → exit 1.
- [x] T9 Split: `UsecaseCreateRequest` shared resolver (de-monolithic
      create capability) + standalone `VerifyUsecaseCapability`
      (provenance receipt `usecase-verify-<entity>-<timestamp>.json`)
      registered in `UseCasePlugin.capabilities`.
- [x] T10 Tests: `test/plugins/usecase/usecase_verify_test.dart`,
      `test/plugins/usecase/usecase_certify_test.dart` (red-green
      evidence in `tdd/test-list.md`).
- [x] T11 Non-behavioral: `dart format .` clean, analyzer clean on
      touched files, CHANGELOG entry.
