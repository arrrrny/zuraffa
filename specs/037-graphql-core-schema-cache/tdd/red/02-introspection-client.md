# Red Evidence — Introspection client (throwing, detailed errors)

**Test file**: `test/graphql/introspection_client_test.dart`
**Behaviors**: B02 — fetch happy path; B03 — HTTP failure detail; B04 —
unreachable endpoint; B05 — GraphQL errors surface field/type; B06 — missing
__schema / query root / malformed JSON / unknown kind
**Spec**: FR-001, FR-002, SC-004

## First-run output (before implementation)

```
$ dart test test/graphql/introspection_client_test.dart

  test/graphql/introspection_client_test.dart:4:8: Error: Error when reading
  'lib/src/graphql/introspection/introspection_client.dart': No such file or
  directory
  test/graphql/introspection_client_test.dart:22:13: Error: Method not found:
  'IntrospectionHttpResponse'.
  test/graphql/introspection_client_test.dart:20:22: Error: Method not found:
  'IntrospectionClient'.
  ... (IntrospectionException / IntrospectionTransport not found — 10+
  occurrences)
00:00 +0 -1: Some tests failed.
```

**Status**: RED ✓ — `lib/src/graphql/introspection/introspection_client.dart`
did not exist when the tests were authored. The null-returning legacy
`GraphQLIntrospectionService` could never satisfy the no-null-on-failure
assertions (B03–B06) by construction.
