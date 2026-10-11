# Plan — Spec 1513 contract lane flutter imports

## Technical Context

- **Language/SDK**: Dart 3.13 stable (pubspec pins `^3.11.0`); pure-Dart root
  package, no Flutter SDK required for the suite (`dart test`).
- **Surfaces**:
  - `lib/src/plugins/tdd/services/contract_test_writer.dart` — the contract
    test templates (`_render`, `_renderUnparseable`) and the subject-import
    computation (`_relativeSubjectPath`).
  - `lib/src/plugins/tdd/services/behavior_test_writer.dart` — the private
    instance `_packageSubjectImport` (#1035) to promote to public static
    `packageSubjectImportFor`.
  - `lib/src/plugins/tdd/commands/gen_command.dart` — `_writersFor` contract
    branch constructs `const ContractTestWriter()` without `flutterTest`
    (line ~1498-1503).
- **Existing machinery reused**: `BehaviorTestWriter.flutterTest` +
  `_testImport` (#1351) — the contract writer mirrors the exact same getter
  shape; `gen_command._isFlutterProject` (pubspec YAML `dependencies: flutter:`
  key check, #1458) — already resolved once per gen and threaded into
  `_writersFor`; `_regenerateStaleStub` already forwards `flutterTest`.
- **Byte-stability mechanics**: the only rendered lines that change are the
  framework import and the subject import. Default path (no flutterTest, no
  resolvable package import) interpolates the identical literals, so the
  golden render is unchanged.

## Data flow (after the fix)

```
zfa tdd gen contract:A1
  → _isFlutterProject(cwd)                    (existing, #1458-safe)
  → _writersFor(..., flutterTest)
      → ContractTestWriter(flutterTest)       (NEW: flag threaded)
          → _testImport                       (NEW: package:test | flutter_test)
          → BehaviorTestWriter.packageSubjectImportFor(test, subject)   (NEW: promoted static, #1035)
              → package:<name>/<under-lib>  | fallback _relativeSubjectPath
          → _render / _renderUnparseable import the resolved URIs
```

## Constitution / constraints check

- Touch surface limited to `contract_test_writer.dart` + `gen_command.dart`
  (+ the promoted helper's home file `behavior_test_writer.dart` visibility
  change — no behavior change there).
- No state machine, lane routing, or loop semantics touched.
- Unit/acceptance writers untouched; their tests must stay green.

## Test strategy

Unit-level writer tests (fast tier, `dart test test/plugins/tdd/services/`)
pin B1–B6; one command-level integration test (`dart test
test/plugins/tdd/commands/`) pins B7 — `_writersFor` threading end to end via
`CliRunner` on a Flutter-detected fixture (pubspec with `dependencies:
flutter:`, no Flutter SDK needed — detection is YAML-only).

## Risks

- `contract_kind_1007_test.dart` pins the relative seam import; its fixture
  has NO pubspec.yaml, so the promoted helper returns null and the relative
  fallback keeps it green. Verified by running the suite.
- Golden/staleness byte-compare: renders must match across binaries only for
  the same host; a Flutter host regenerating a pure-Dart-era stub now
  correctly reports staleness (regenerated verdict) — that is the intended
  remedial behavior (#1320 precedent), not drift.
- The staleness mirror is context-seeded: `_regenerateStaleStub` copies the
  enclosing `pubspec.yaml` into the temp mirror before rendering, so a
  re-render resolves the SAME `package:` subject import the real `gen`
  writes. Without it the mirror had no package identity, `packageSubjectImportFor`
  returned null there, and every re-render permanently downgraded the
  promoted import back to the relative shape (finding 1 on the #1531 review;
  pinned by B9).
