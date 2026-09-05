# Contract: `engine.receipt.json` (v2 — issue #1109 / #1014 CERT-GATE)

**Location**: `specs/<feature>/tdd/engine.receipt.json` (project-root relative), created on demand.

**Written by**: `zfa make engine <Entity>` after the mock certifier runs.
**Read by**: #1014 CERT-GATE, `zfa engine check`.

## Schema

```json
{
  "schema": "engine.receipt.v2",
  "entity": "User",
  "methods": [
    {
      "name": "get",
      "mock_certified": true,
      "mock_class": "MockUserDataSource"
    },
    {
      "name": "create",
      "mock_certified": true,
      "mock_class": "MockUserDataSource"
    }
  ],
  "source_files": [
    "lib/src/domain/entities/user/user.dart",
    "lib/src/domain/usecases/user/get_user_usecase.dart",
    "lib/src/domain/services/user_service.dart",
    "lib/src/domain/repositories/user_repository.dart",
    "lib/src/data/datasources/user/user_remote_data_source.dart",
    "lib/src/di/user_usecase_di.dart"
  ]
}
```

## Rules

1. One entry in `methods` per method requested/generated on the run.
2. `mock_certified` is `true` only when the certifier verified the method on the mock
   datasource and the seeded data fixture exists; any `false` fails `zfa engine check`.
3. `mock_class` is the mock class name certified for the method.
4. `source_files` lists every file the run wrote, project-root relative, sorted.
5. Re-runs overwrite the file atomically (write temp, rename) — never append, never merge.
6. Written even when some methods are uncertified (the `false` values are the signal), but
   the generation command still reports the failures in its output.
