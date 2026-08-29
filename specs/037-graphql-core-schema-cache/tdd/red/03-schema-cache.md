# Red Evidence — Schema cache per-name layout

**Test file**: `test/graphql/schema_cache_037_test.dart`
**Behaviors**: B07 — dual-layout artifacts; B08 — overwrite + prev rotation;
B09 — missing name error with path; B10 — auto-create dir, no partial writes
**Spec**: FR-001, US-1 scenarios 1–3, SC-001, SC-004

## First-run output (before implementation)

```
$ dart test test/graphql/schema_cache_037_test.dart

  test/graphql/schema_cache_037_test.dart:6:8: Error: Error when reading
  'lib/src/graphql/introspection/introspection_client.dart': No such file or
  directory
  test/graphql/schema_cache_037_test.dart:14:1: Error: Type
  'IntrospectionTransport' not found.
  test/graphql/schema_cache_037_test.dart:42:34: Error: The method 'pull'
  isn't defined for the type 'SchemaCache'.
  test/graphql/schema_cache_037_test.dart:151:21: Error:
  'IntrospectionException' isn't a type.
  ...
00:00 +0 -1: Some tests failed.
```

**Status**: RED ✓ — the pre-existing `SchemaCache` had `load`/`save` only
(single anonymous `schema.json`, `UnimplementedError` fetch path); the per-name
`pull`/`loadPrevious`/`hasSchema`/`write` API did not exist.
