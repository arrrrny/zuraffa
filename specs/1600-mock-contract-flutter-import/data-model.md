# Data Model — Spec 1600

No persisted data entities change. This feature touches two in-memory
artifact shapes and one on-disk artifact whose schema is unchanged.

## Touched shapes

### `MockContractTestWriter` (value object)

| Member | Kind | Change |
| -- | -- | -- |
| `flutterTest` | `bool` field, default `false` | NEW |
| `testImport` | `String` getter | NEW — `'package:flutter_test/flutter_test.dart'` when `flutterTest`, else `'package:test/test.dart'` |
| `render(...)` | method | interpolates `testImport`; all other bytes unchanged |

### `MockCertificationSandbox` (service)

| Member | Kind | Change |
| -- | -- | -- |
| `flutterTest` | `bool` field, default `false` | NEW |
| sandbox pubspec | emitted text | `flutterTest: false` → today's exact bytes; `true` → adds `flutter: sdk: flutter` + `flutter_test` sdk dep |
| toolchain executable | selection | `dart` (unchanged) | `flutter` when flag set |
| `MockCertificationRun.runner` | `String` | `'dart'` (unchanged) | `'flutter'` when flag set; no longer a hardcoded literal |

### `mock-cert.<Entity>.json` receipt (on disk)

**Schema unchanged.** `contractDigest` continues to pin the exact certified
bytes (which now differ per host shape); per-method `satisfied` outcomes
come from the same JSON-event parsing on either toolchain.

## State transitions

`create --certify` on a Flutter host:

```
detect host (pubspec) ──► flutter SDK present? ──► yes → sandbox(flutter) → green receipt | honest red
                                              └─► no  → warn + NO receipt + generation-governed exit
```

The no-receipt branch is the existing `certSandboxUnresolved` state — no new
state machine, no new marker.
