# Issue #1189 — [PUB] core master requires analyzer ^14.3.0 as a regular dependency — Flutter consumers need a dependency_overrides

- **Severity**: critical
- **Component**: pubspec / packaging (root package `zuraffa`)
- **Reported via**: sandbox bring-up, #1111 stage set
- **Record provenance**: this file was reconstructed verbatim from the bug
  report handed to the fix agent (no `issue.md` was committed in this
  directory before the fix landed; the task brief is the canonical record).

## Observed

A Flutter app consuming zuraffa from master (path/git dep) fails `pub get`:

```
Because every version of zuraffa from path depends on analyzer ^14.3.0,
zuraffa from path is incompatible with test …
```

`flutter_test`'s graph pins the shared test spine (`test_api`, `matcher`)
for the reachable `test` versions, and core master declared
`analyzer: ^14.3.0` **and `test: any`** as REGULAR dependencies. The
published 6.1.0 pins analyzer 14.1.0 and resolves for pure-Dart consumers.

Reproduction on the fix branch's toolchain (Flutter 3.47.2 / Dart 3.13.2)
adds precision — the resolver's terminal verdict on the pre-fix tree is:

```
And because every version of flutter_test from sdk depends on test_api
0.7.12 and every version of zuraffa from path depends on test any, zuraffa
from path is incompatible with flutter_test from sdk.
So, because example depends on both zuraffa from path and flutter_test
from sdk, version solving failed.
```

Full solver dump: `red-evidence-flutter-pubget.md` (next to this file).

## Impact

Every Flutter consumer of core master (git dep, or the next publish if
unchanged) needs a `dependency_overrides` entry in the app to resolve;
CI matrices that resolve strictly fail. In-repo, `dart pub get` at the
root (which recurses into `example/`) fails, and every
`flutter pub get` / `flutter analyze` / `flutter test` that recurses into
`example/` dies. CI never caught it because every job resolves with
`--no-example`.

## Suggestion (from the report)

- If analyzer is only needed for generator/dev code paths, move it to
  dev_dependencies (consumers get it transitively only where actually
  required);
- Or widen to `>=14.0.0 <15.0.0` if 14.0–14.2 truly work;
- Either way, add a Flutter-consumer smoke test (a tiny app depending on
  core + flutter_test, pub get as the gate) so the next constraint bump
  cannot silently break Flutter resolution again.

## Hard constraints

- Fix the constraint.
- Add a Flutter smoke gate.
- One PR for the bug.
