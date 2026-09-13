# TDD Cycle Log — Spec 1601 (append-only)

## Baseline (pre-loop)

- Feature: specs/1601-package-plugin-scaffold (issue #678; epic #214).
- Suite state before any behavior work: `dart test test/package_sdk/` →
  **43 passing, 0 failing** on branch `1601-package-plugin-scaffold`
  (HEAD 69e049e9 + spec artifacts). Working tree carries unrelated
  spec-1600 mock edits (not touched by this feature).
- Test list: 11 behaviors (B1–B11). No guards — all-new surface, so all
  behaviors are missing-API red pre-fix. Slow tier: B9 only.
- Derivation: LLM-guided fallback (`.zfa.json` absent in the framework
  repo; `zfa tdd plan` needs project wiring) per tdd-plan skill Step 0.

## Cycle C1 — the plugin scaffold engine (B1–B8, B10, B11)

- **RED** (batch, recorded before any implementation):
  `dart test test/package_sdk/plugin_scaffold_test.dart`
  → `00:00 +0 -1: Some tests failed.` — loading failure:
  `package:zuraffa/src/package/plugin_scaffold.dart` /
  `plugin_family_names.dart` do not exist (missing-API red for B1–B8,
  B10, B11; B9 e2e file not yet written — separate cycle).
- **GREEN**: implement `PluginFamilyNames` + `PluginScaffold` +
  `package plugin` subcommand (below).
