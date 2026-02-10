# Migration Guide to Zuraffa v2

This guide helps existing Zuraffa users migrate projects to v2. It focuses on code generation updates, UseCase APIs, and entity conventions.

## Quick Checklist

- Update dependency to a v2 release
- Regenerate code with the v2 CLI
- Update UseCase call sites to handle Result
- Align entity paths and Zorphy usage
- Review breaking changes list

## 1) Update Dependencies

Update your pubspec to the latest v2 version and fetch packages:

```yaml
dependencies:
  zuraffa: ^2.8.0
```

```bash
flutter pub get
```

If you use entity generation, ensure Zorphy is available:

```yaml
dependencies:
  zorphy: ^1.5.0
  zorphy_annotation: ^1.5.0
```

## 2) Regenerate Code

Regenerate with the v2 CLI to align with the current architecture:

```bash
zfa generate Product --methods=get,getList,create,update,delete --data --vpc --state --di --force
```

If you are in a subdirectory (like example), make sure the output is correct:

```bash
zfa generate Product --methods=get,getList,create --output=lib/src --force
```

## 3) Update UseCase Call Sites

v2 UseCases return Result instead of raw values, so call sites should handle success and failure explicitly.

Before:

```dart
final product = await getProductUseCase(params);
setState(() => _product = product);
```

After:

```dart
final result = await getProductUseCase(params);
result.fold(
  (product) => setState(() => _product = product),
  (failure) => setState(() => _error = failure),
);
```

## 4) Update Params Types

Use query and update parameter wrappers where required:

Before:

```dart
await updateProductUseCase(id, data);
```

After:

```dart
final params = UpdateParams<String, ProductPatch>(id: id, data: patch);
await updateProductUseCase(params);
```

For list queries:

```dart
await getProductListUseCase(const ListQueryParams());
```

## 5) Ensure Entity Locations

Entities should live in:

```
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

Example:

```
lib/src/domain/entities/product/product.dart
```

## 6) Review Breaking Changes

Read the full list of breaking changes:

- [BREAKING_CHANGES.md](file:///Users/arrrrny/Developer/zuraffa/docs/BREAKING_CHANGES.md)

## Troubleshooting

**Entity not found**
- Ensure the entity file exists at the expected path.
- Regenerate entities using the entity CLI if needed.

**Import errors after generation**
- Run generation with --force to normalize file structure.
- Confirm the output directory is correct.

**Result handling errors**
- Update controllers and views to handle Result.fold or pattern matching.

**CancelToken errors**
- Pass cancelToken only when needed, otherwise omit it.

## FAQ

**Do I need to regenerate everything?**  
Yes. Regenerating with v2 aligns your code with the current architecture and prevents subtle API mismatches.

**Can I opt out of Zorphy?**  
Yes. Use configuration defaults or CLI flags to disable Zorphy if you maintain manual entities.
