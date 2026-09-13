# Implementation Plan: 1530-generated-code-fails-own-gate

**Branch**: `feat/1530-generated-code-fails-own-gate` | **Spec**: `specs/1530-generated-code-fails-own-gate/spec.md` | **Status**: In progress

## Technical Context

**Language/Version**: Dart SDK ^3.11.0 (monorepo resolves on 3.13.3), pure Dart — no Flutter surface.
**Dependencies**: `code_builder` + `dart_style` (emission), `yaml` (read-only pubspec detection), `test` (dev). Empty `hide: []` in code_builder emits NO combinator (verified by probe) — "drop the hide entirely" falls out of an empty filtered list.
**Storage**: textual pubspec patching (no YAML rewrite); `.dart_tool/package_config.json` read-only for the seed.
**Testing**: `dart test` fixtures under `test/` — hermetic temp-dir fixtures (existing `test/utils/zuraffa_barrel_exports_test.dart` pattern) + fake-`zfa`-bin make integration tests (existing `test/plugins/tdd/make_command_test.dart` pattern).

## Primary Technical Decision — hide combinator emission

Single choke point: `ZuraffaBarrelExports` (`lib/src/utils/zuraffa_barrel_exports.dart`) + its callers via `EntityUtils.barrelHideNames` / `CommonPatterns.barrelHideNamesForTypes`. Emission sites (all route through the filter, all keep their `if (barrelHide.isEmpty) → no combinator` shape):
- datasource builders: `local_generator.dart`, `remote_generator.dart`, `interface_generator.dart` (`package:zuraffa/zuraffa.dart`)
- mock builders: `mock_datasource_builder.dart`, `failing_mock_provider_builder.dart` (`package:zuraffa/mock.dart`)
- `provider_builder.dart`, `sqlite_datasource_builder.dart`, repository `interface_generator.dart`, usecase `entity_usecase_generator.dart`

Changes:
1. **FR-001** — `filter()` unresolved seed: return `const []` (drop combinator) instead of the legacy keep-all fallback. Callers already emit no combinator for an empty list, so no emission-site churn.
2. **FR-002** — `_collectFromBarrel` combinator-awareness: parse each `export` line's `show`/`hide` combinators. `show` present → the line contributes only shown names from the target file; `hide` present → excluded names are subtracted. Unqualified lines keep current behavior (every top-level `class`/`mixin`/`enum`/`typedef` declaration in the target file). `package:` targets remain skipped (conservative under-collection is safe — it can only lose #942 protection for exotic names, never emit an unverified hide).
3. **FR-003** — nested barrel relative resolution: recurse with the exporting barrel's own directory as the base for directory-relative targets (`src/core/params/index.dart` + `export 'query_params.dart';` → `lib/src/core/params/query_params.dart`), keeping the existing depth guard.

Rationale: the emission sites' `hide` lists are entity symbols (name + `Patch` pair); the seed is the only verification source. The bug chain (reproduced): target without resolvable `zuraffa` → seed null → legacy keep-all → `hide Task, TaskPatch` baked into generated files → `undefined_hidden_name` → analyze gate red. Dropping the combinator when unverifiable trades a guaranteed warning for the narrow #942 collision case ONLY in the unresolvable window; FR-005's ensure pulls the target out of that window (declaration present → `pub get` → seed resolves → verified hides emitted again, byte-identical to today's compiling output — FR-010).

## Primary Technical Decision — `package:zuraffa` dependency ensure

New `lib/src/core/dependencies/pubspec_zuraffa_ensure.dart` — `PubspecZuraffaEnsure`:
- Detection: YAML parse (read-only) of `dependencies:` — mirroring `PubspecSkinDependencyPatcher` (same class shape, same refusal contract for inline mappings via `UnsupportedError`, same `FormatException` on unparseable YAML).
- Patch: textual (comment/blank-line/order preserving), inserts at the END of the `dependencies:` block; appends a new block when absent; expands inline-empty `dependencies: {}`.
- Constraint: `^6.0.0` — mirrors `DependencyWirer.standardSet`'s pure-Dart `zuraffa` entry (single documented constant).
- Override-only pubspecs: `dependency_overrides:` is NOT a declaration (#1190 contract) — the entry is still added under `dependencies:`.
- Offline-safe: NO process spawn for the declaration itself. Re-resolution stays the existing flows' job (`zfa build`/`build_runner`/CI `pub get`, the #1265 auto-add when it runs online).

Hook: `lib/src/commands/make_command.dart`'s existing #1190/#1265 pubsync post-pass (lines ~1043-1077). The gap is already computed there from the files THIS RUN wrote (`_pubsyncGapForFiles` → `GeneratedImportScanner.analyzeFiles`). Before the existing `PubspecAutoAdd` arm: if the run's imported packages include `zuraffa` AND the pubspec's `dependencies:` lacks it → run the ensure, print the receipt line (`✅ Ensured zuraffa ... in pubspec.yaml dependencies`), record into the same summary path (`pubsyncAutoAdded` naming). Failures (`FormatException`/`UnsupportedError`) degrade to the existing `⚠️ pubspec.yaml doesn't declare ...` gap-warning path — the run's artifacts stay correct, the diagnosis names the manual fix.

Deliberately NOT done: `zfa tdd init` patchers stay untouched (init-time ensure is a different surface; the spec's trigger is "generated files import package:zuraffa", which is the make post-pass); no `pub get` spawn (network-free guarantee; `pub add` for OTHER packages keeps its existing semantics).

## Primary Technical Decision — green-with-failed-build receipt

`lib/src/plugins/tdd/commands/make_command.dart` tolerated path (~line 1600): after the two existing explanation lines and BEFORE `postRun = toleratedRun`, print the warnings block from `failed.output`:
- Extract `warning -` lines with the same regex shape as `_logWarningsOnlyGateRefusal` (`^\s*warning\s*-\s.*$`), print verbatim (trimmed-indent preserved text) capped at 10 + a remainder line — reusing the #1407 presentation contract.
- No `warning -` lines → print `   no analyzer warnings reported — the build failed for another reason (see output above).`
- Grading untouched: `_isWarningsOnlyBuildGateRefusal`, `_toleratedTerminalBuildFailure`, the #942 errors refusal, and `_printSummary` are not modified. This is print-only.

## Technical Context keywords

hide combinator emission; package:zuraffa dependency ensure; green-with-failed-build tolerance; zfa build gate

## Constitution Check (repo conventions)

- **VII (pure-Dart CLI)**: all changes pure Dart — no Flutter imports.
- **Errors-are-an-API**: ensure refusals throw typed errors (`FormatException`/`UnsupportedError`) that callers degrade into named remedies.
- **Honest receipts**: the receipt change ADDS information to a tolerated outcome; it does not reclassify anything.

## Risks & Mitigations

| Risk | Mitigation |
| -- | -- |
| Dropping unseeded hides loses #942 protection in the unresolvable window | FR-005 ensure pulls targets out of the window; FR-010 locks the seeded path byte-identical; the window's alternative is the gate-red warning this spec fixes |
| Over-collection in `_collectFromBarrel` hides real exports from verification | Combinator-aware collection (FR-002) makes the surface MORE precise; `package:` re-exports stay skipped (documented conservatism) |
| Pubspec patcher mangles exotic pubspecs | Refuses loudly on inline mappings; YAML-parse guard for detection; textual patch tested against comment/formatting fixtures (US2-3) |
| Receipt verbosity noise in voluminous transcripts | #1407 cap contract (10 + remainder) reused verbatim |

## Post-implementation verification

`dart analyze` (repo) → no new warnings; `dart test` scoped to touched lanes; generated-output probe against `/tmp/repro1530`-style fixture re-run: no `hide Task, TaskPatch`, pubspec declares `zuraffa` after offline run; `dart format` clean on touched files.
