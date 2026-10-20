# Bug Assessment: #1928 regression — the #1923 merge deleted the `entityFileExists` escape and the surviving `_deriveForeignPageShape` check misses Zorphy's `$`-prefixed field types, so named per-member paginated reads still refuse as `unknown return type`

- **Slug**: `1955-zorphy-dollar-page-shape`
- **Created**: 2026-10-20
- **Source**: https://github.com/arrrrny/zuraffa/issues/1955
- **Verdict**: valid
- **Severity**: high (the consuming project cannot regenerate `test/mock/zik_zak`; the seam stays hand-written with a `$` re-export workaround, and the closed #1928 makes the gap invisible to issue-status tracking)

## Report (summarized from the issue, verified against `330661b9`)

#1928's fix (PR #1942) added an `_isHonestArbitraryReturn` helper carrying the
`EntityAnalyzer.entityFileExists` escape that let a named per-member route
accept a foreign paginated return. The later #1923 merge (PR #1936) rewrote
both refusal sites around `_deriveForeignPageShape` and deleted that helper —
at `330661b9` the symbol no longer exists in
`lib/src/plugins/mock/builders/mock_datasource_builder.dart`.

The surviving derivation gates on file existence (`entityFileExists` at
`:1913`) and then requires the foreign entity's analyzed fields to contain
exactly `List<ZikZak>`. But a REAL Zorphy part-file entity declares its fields
against the `$`-prefixed abstract supertype:

```
$ dart run tool/zk_zp_probe.dart
exists(ZikZakPage) = true
fields = {items: List<$ZikZak>, hasMore: bool}
```

`_deriveForeignPageShape`'s normalizer strips only `?` and spaces, so
`List<$ZikZak>` ≠ `List<ZikZak>`, the derivation returns `null`, and the
caller keeps the #1850 refusal:

```
zfa mock create ZikZak --methods "getZikZaks:ListQueryParams<ZikZak>->ZikZakPage,remove:String->void" --dry-run
# ❌ Error: Invalid argument(s): unknown return type ZikZakPage for member getZikZaks
```

Read-only `zfa mock verify ZikZak` still passes (the tree keeps a
hand-authored interface), so only regeneration is blocked — which is why the
regression went unnoticed.

## Symptom

`zfa mock create ZikZak --methods "getZikZaks:ListQueryParams<ZikZak>->ZikZakPage,remove:String->void"` refuses with
`unknown return type ZikZakPage for member getZikZaks` (exit 1) on a project
whose `ZikZakPage` is a Zorphy part-file entity. Expected: exit 0 and a
generated `ZikZakDataSource` / `ZikZakMockDataSource` whose `getZikZaks`
returns `Future<ZikZakPage>` with the honest paginated body derived from the
`ZikZak` fixture.

## Reproduction

Unit-tier, on the unfixed tree (`test/plugins/mock/mock_datasource_builder_1928_test.dart`):

1. Seed `domain/entities/zik_zak_page/zik_zak_page.dart` as a real Zorphy
   part-file entity — `@Zorphy() abstract class $ZikZakPage` with
   `List<$ZikZak> get items; bool get hasMore;`.
2. `EntityAnalyzer.analyzeEntity('ZikZakPage', …)` →
   `{items: List<$ZikZak>, hasMore: bool}` (passes — the fixture reproduces
   the real field shape; the #1923 fixture used a hand-written
   `List<ZikZak>` entity, which is why it could not catch this).
3. `MockDataSourceBuilder.generateMockDataSource` with
   `getZikZaks:ListQueryParams<ZikZak>->ZikZakPage` → throws
   `Invalid argument(s): unknown return type ZikZakPage for member
   getZikZaks` at `mock_datasource_builder.dart:1820`.

## Suspected Code Paths

- `lib/src/plugins/mock/builders/mock_datasource_builder.dart:_deriveForeignPageShape`
  — the `normalize` closure (only `?`/spaces) compared against
  `List<$entityName>`; every refusal path (create at `:545`, shape-drift
  repair at `:897`/`:1805`) flows through it, so one fix covers all.
- `lib/src/utils/entity_analyzer.dart:_parseEntityFields` — parses the
  `$`-prefixed class and its getters verbatim; the `$` reaches callers
  by design (entities are Zorphy-first on public v7 surfaces).

## Remediation

Strip Zorphy's supertype prefix in the normalizer:

```dart
String normalize(String type) => type
    .replaceAll('?', '')
    .replaceAll(' ', '')
    .replaceAll('\$', '')   // Zorphy supertype prefix
    .trim();
```

plus a regression test on a real Zorphy part-file entity that asserts BOTH the
`analyzeEntity` output (`List<$ZikZak>`) and the accepted method shape, so a
future rewrite of the refusal path cannot silently drop the fix again.
