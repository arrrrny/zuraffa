# Bug Issue: MOCK-CREATE: --force regenerates the mock datasource but leaves the STALE datasource interface when --methods changes

- **Slug**: 1418-mock-force-regen-interface
- **Fetched**: 2026-09-16
- **Issue**: 1418
- **URL**: https://github.com/arrrrny/zuraffa/issues/1418
- **State**: open
- **Severity**: unknown
- **Author**: arrrrny
- **Labels**: (none)

## Body

### Command that failed

`zfa mock create Deal --methods getList --certify --force` (zik_zak_v2, zfa v6.2.2 @ core 27644a49; entity `Deal` with nested `Listing`/`ListingOffer`)

Sequence to reproduce:
1. `zfa mock create Deal --methods list` → writes `deal_datasource.dart` with `Future<List<Deal>> list(NoParams params);` and a `DealMockDataSource` with **no** method body (receipt labeled DRIFT).
2. `zfa mock create Deal --methods getList --certify --force` → regenerates the **mock** with `Future<List<Deal>> getList(ListQueryParams<Deal> params)` but does **not** touch the existing interface.

### Expected

`--force` should regenerate the whole generated pair (interface + mock) so the emitted `DealDataSource` declares `getList(ListQueryParams<Deal>)` and the certified pass proves a conforming pair.

### Actual

```
❌ mock certification for Deal failed — unsatisfied: list
❌ Error: mock certification failed for Deal: dart analyze: 7 issue(s), 1 error(s)
  error - lib/src/data/datasources/deal/deal_mock_datasource.dart:12:7 -
    Missing concrete implementation of 'DealDataSource.list'.
  warning - deal_mock_datasource.dart:21:22 - The method doesn't override an inherited method.
```

The interface keeps the stale `list(NoParams)` member; the mock implements `getList(...)` → the pair cannot compile and certification dead-ends no matter how many times `--force` re-runs.

### Secondary bug in the same output

The generated files import with hides that the target library does not export:

```dart
import 'package:zuraffa/zuraffa.dart' hide Deal, DealPatch;
import 'package:zuraffa/mock.dart' hide Deal, DealPatch;
```

`zuraffa.dart`/`mock.dart` export no `Deal`/`DealPatch` (names derived from the entity), so the analyzer reports `undefined_hidden_name` warnings on every generated datasource file. These warnings are inside GENERATED files and then fail `zfa build`'s analyze gate (error/warning severity) during `zfa tdd run` refactor passes — poisoning the whole engine lane for the project.

Also seen: the emitted `test/mock/deal/deal_mock_contract_test.dart` carries an `unused_import` warning (`deal_mock_data.dart`), same gate concern for suites that analyze test/.

### Root cause (observed)

The interface write path is create-if-absent and is not invalidated by `--force` (nor by a `--methods` selection change), while the mock body is always regenerated from the current `--methods` — the pair can drift. The hide list is emitted unconditionally from the entity name without checking the library's export surface.

### Suggested fix

1. `--force` regenerates (or deletes-then-writes) the `<entity>_datasource.dart` interface together with the mock.
2. Emit `hide X, Y` only for names the target library actually exports (or drop the hide entirely).
3. Certification's scoped analyze for generated files could tolerate `undefined_hidden_name` in files the generator owns until (2) ships.

## Comments

None.
