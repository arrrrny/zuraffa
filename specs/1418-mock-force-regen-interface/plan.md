**Template Version**: `zuraffa-1.0`

# Plan: 1418-mock-force-regen-interface

## Technical Context

- Language/Dart SDK: `^3.11.0` (repo constraint), toolchain Dart 3.13.4 stable.
- CLI surfaces involved:
  - `lib/src/plugins/mock/builders/mock_builder.dart` — THE fix site for
    the force path. `MockBuilder.generate` (L195–234) guards the interface
    emission behind `if (!await fileSystem.exists(interfacePath))`
    (L220) — create-if-absent. Under `--force` an existing stale
    interface is never rewritten while
    `dataSourceBuilder.generateMockDataSource(config)` always rebuilds
    the mock body from the current `--methods` (fresh path writes with
    `force: options.force`), so the pair drifts. The guard becomes
    `!exists || (config.force && !config.revert)`.
  - `lib/src/plugins/datasource/builders/interface_generator.dart` —
    `DataSourceInterfaceBuilder.generate` (NOT modified). Its exists
    branch `if (exists && (config.appendToExisting || !config.force))`
    (L337–338) routes force runs to the fresh-write path (L441–450) with
    `force: options.force` → `FileUtils.writeFile` overwrites → ledger
    action `overwritten`. The mock lane never sets `appendToExisting`
    (`create_mock_capability._generateFiles` builds `GeneratorConfig`
    without it → default false), so `exists && !force` is the only other
    branch and the mock lane's non-force skip at the `MockBuilder` level
    keeps the interface writer entirely out of the picture.
  - `lib/src/plugins/mock/mock_plugin.dart` — `generate` re-delegates to
    a fresh `MockPlugin` when `config.force != options.force` (L186–203),
    so by the time `MockBuilder` runs, `options.force == config.force`;
    the interface builder constructed with the same `options` overwrites
    with the run's force flag. Read-only confirmation of the fix's
    precondition.
  - `lib/src/utils/file_utils.dart` — `writeFile` skip semantics
    (L53–66, NOT modified): `exists && !force` → `skipped`; force →
    `overwritten`.
  - `lib/src/utils/zuraffa_barrel_exports.dart` — THE fix site for the
    hide emission. `_resolve` (L95–125) walks ONLY
    `lib/zuraffa.dart` (L118) while the mock lane imports
    `package:zuraffa/mock.dart`; the mock barrel's own surface is never
    checked. Adds a mock-surface walk (local declarations along
    `lib/mock.dart`'s export chain, unioned with the zuraffa surface
    when the chain carries a bare combinator-free
    `export 'package:zuraffa/zuraffa.dart';`) and a `filterMock`
    companion to `filter`.
  - `lib/src/utils/entity_utils.dart` — `barrelHideNames`
    (L138–139, NOT modified): stays the zuraffa-surface filter for
    zuraffa.dart imports. The mock lane switches its two mock-barrel
    emission sites to a mock-surface filter.
  - `lib/src/plugins/mock/builders/mock_datasource_builder.dart` —
    emission site (L111–122): builds `barrelHide` via
    `EntityUtils.barrelHideNames` and emits
    `Directive.import('package:zuraffa/mock.dart', hide: barrelHide)`
    (L122). Switches the hide source to the mock-barrel filter.
  - `lib/src/plugins/mock/builders/failing_mock_provider_builder.dart` —
    same emission shape (L77–84). Switches identically (spec 1110 twin
    shares the import signature).
  - `lib/src/plugins/mock/services/mock_certification.dart`,
    `lib/src/plugins/mock/certification/*` — certification logic and
    emitted contract artifacts. READ-ONLY (hard constraint FR-008): the
    structural check extracts the contract from the on-disk interface,
    so once the interface regenerates the pair conforms and the gate
    passes with zero certification-side changes.
- Sibling context (same failure family, already merged): #1570
  (mock-lane drift repair — explicitly left the interface writer
  untouched) and #1530 (verified-surface hide emission against
  `zuraffa.dart`). This feature closes both residuals the issue names:
  the interface half of the pair under `--force`, and the verification
  target of the mock-barrel hide.

## Root Cause (verified by reproduction path)

1. `mock_builder.dart:220` — `if (!await fileSystem.exists(interfacePath))`.
   The interface write path is create-if-absent and is not invalidated by
   `--force` (nor by a `--methods` change), while the mock body is always
   regenerated from the current `--methods` with
   `force: options.force`. First run (`--methods list`) writes
   `list(NoParams)` into the interface; second run
   (`--methods getList --force`) rewrites the mock to implement
   `getList(ListQueryParams<Deal>)` and skips the interface →
   `Missing concrete implementation of 'DealDataSource.list'` → the
   certification's scoped analyze fails on the drifted pair, every time.
2. `zuraffa_barrel_exports.dart:118` — the resolver's single walk target
   is `lib/zuraffa.dart`, but the mock lane hides from
   `package:zuraffa/mock.dart`. Correctness today rests on
   `lib/src/mock/mock.dart` bare-re-exporting the full zuraffa surface —
   an accident of the current barrel layout, not a verified property.
   #1418's fix suggestion (2) — "Emit hide X, Y only for names the target
   library actually exports" — requires walking the imported library.

## Remediation Design

### Change 1 — force-aware interface regeneration guard (FR-001/002/006/007)

```dart
// mock_builder.dart (was: if (!await fileSystem.exists(interfacePath)))
if (!await fileSystem.exists(interfacePath) ||
    (config.force && !config.revert)) {
  files.add(await interfaceBuilder.generate(config));
}
```

- Non-force: unchanged (create-if-absent; existing file never reaches the
  builder → the append path cannot fire from the mock lane → byte-stable).
- Force + !revert: the builder regenerates the interface fresh from
  `config.methods` through its existing fresh-write path → `overwritten`.
- Force + revert: revert precedence wins (mirrors the #1570 staleness
  arming condition `!options.force && !config.revert`).
- Absent interface: emitted in every mode (#417 guarantee).
- dryRun: honored inside `FileUtils.writeFile`/`FileUtils.deleteFile`, no
  new dry-run surface needed.

### Change 2 — mock-barrel verified hide emission (FR-004/005)

`ZuraffaBarrelExports` gains a second resolved surface:

- `_resolve` additionally walks `lib/mock.dart` collecting the mock
  barrel's LOCAL declaration surface along its export chain (relative
  targets only; `package:` targets other than the zuraffa barrel stay
  skipped — over-collection is the unsafe direction, #1530 FR-003
  philosophy). When the chain contains a BARE (show/hide-free)
  `export 'package:zuraffa/zuraffa.dart';`, the zuraffa surface is part
  of the mock surface (union) — that is what the bare re-export asserts.
  A combinator-carrying re-export does NOT union (it may subtract).
- `filterMock(hides)` mirrors `filter`'s contract against the mock
  surface: unresolved → empty list → no combinator.
- `filter` keeps its exact current behavior (zuraffa surface) — the
  interface writer and every other emission site stay untouched.
- The two mock-barrel emission sites (`mock_datasource_builder.dart`,
  `failing_mock_provider_builder.dart`) switch to the mock-barrel filter.
- Depth caps mirror the existing walker (same bounds, same
  under-collection-is-safe doctrine).

### Why the certification passes without touching it (FR-003)

`MockCertificationService.certify` extracts `interfaceMethods` from the
on-disk interface and `implementedMethods` from the mock, then computes
`missingMethods`/`inventedMethods`. Post-fix, the force-regenerated
interface declares exactly the current `--methods` and the fresh mock
implements exactly those — both sides read the same source of truth, so
the structural check is empty and the gate's scoped analyze sees a
compiling pair. The certification files stay byte-identical.

## Alternatives Considered

- **Delete-then-write the interface under force** (issue's "or
  deletes-then-writes"): rejected — two ledger entries and a window
  where the import target is missing; the builder's fresh-write path
  already implements atomic overwrite with the same `overwritten` action
  the datasource plugin reports.
- **Unconditionally call the interface builder (datasource-plugin
  shape)**: rejected — on the non-force path it would route existing
  files into the interface builder's APPEND branch (`exists && !force` →
  `updated`), widening the #1570 hard constraint instead of preserving
  it. The force-aware guard keeps the non-force byte contract.
- **Union the mock surface unconditionally** (assume the re-export):
  rejected — a future combinator-carrying mock barrel would re-introduce
  the exact `undefined_hidden_name` class this fixes.
- **Drop the hide entirely from the mock import** (issue's "or drop the
  hide"): rejected — it trades a warning for an `ambiguous_import` error
  class (#942) the hide exists to prevent.

## Verification Strategy

- Behavior tests at the `MockBuilder` level (force regenerates the
  interface from changed methods; pair conformance via the same
  extraction primitives the certification uses; non-force byte
  stability; absent-interface emission; dry-run; revert precedence;
  `repo`-derived path stability; idempotence).
- Resolver unit tests (`filterMock` vs `filter`: diverged surface, bare
  re-export union, unresolved surface, combinator-carrying re-export).
- Emission-level assertion: the mock datasource's
  `package:zuraffa/mock.dart` import carries only mock-verified names.
- Full targeted regression: mock plugin suites, 1570 suite, 1530 hide
  suites, 942 suite, capability/certify-gate suites.
- `dart analyze` on changed files; `dart format lib test` per AGENTS.md.
