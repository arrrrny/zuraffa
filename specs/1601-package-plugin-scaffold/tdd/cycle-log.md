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

- **Reconciliation** (mid-loop): a parallel workstream's `stash` commit
  (9555fc80, issue #1604 / spec 1444 lineage) landed a complete
  `PluginScaffold` implementation + `zfa package create-plugin` command on
  this branch while the loop was red. Decision: the spec-1601 behaviors
  became the verification suite over that implementation, and the loop
  closed the real gaps via TDD deltas:
  1. `repository`/`--repo` option (FR-012) — repo slug was hardwired.
  2. Framework path overrides placement (FR-006/FR-013) — `--zuraffa-path`
     previously wrote a path dep into `dependencies` (unpublishable); now
     the hosted constraint stays and the path rides
     `dependency_overrides` in every package.
  3. `zfa package plugin` alias (FR-001 command surface).
  4. `PluginScaffold.platformsFromCsv` public contract (FR-005/FR-010) —
     command parsing now delegates to the engine.
  5. Explicit `--description` stamps role pubspecs (FR-012) — core and
     adapter descriptions previously ignored it.
  Spec Assumptions updated to match delivered reality (logged, not silent):
  initial version **0.1.0** (was assumed 1.0.0); name derivation strips the
  `zuraffa_` prefix for class nouns (`Ffi`, not `ZuraffaFfi`).
- **GREEN** (cycle C1 close):
  `dart test test/package_sdk/plugin_scaffold_test.dart`
  → `00:03 +15: All tests passed!` — B1–B8, B10, B11 driven to done
  (15 test cases over 11 behaviors; committed 3472ad8d).
