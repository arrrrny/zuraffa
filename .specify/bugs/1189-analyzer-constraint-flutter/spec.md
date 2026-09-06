# Bug spec — Issue #1189 (Flutter-consumer resolution)

Source: `assessment.md`. The "feature" is the bug; required behavior =
acceptance criteria; reproduction steps = failing-test scenario.

## Required (fixed) behavior

- **BR-1**: `flutter pub get` inside a Flutter app whose only relevant
  dependencies are `zuraffa` (path to this checkout) and `flutter_test`
  (sdk) MUST succeed with ZERO `dependency_overrides` entries.
- **BR-2**: `dart pub get` at the repo root — which recurses into
  `example/` — MUST succeed.
- **BR-3**: The public export surface (`package:zuraffa/zuraffa.dart`,
  including the analyzer-importing `src/core/ast/*` exports) MUST compile
  and run under the Flutter consumer graph (`flutter test`).
- **BR-4**: The widened analyzer constraint MUST be honest: the package
  MUST analyze clean (`dart analyze lib test` exit 0, info count no
  greater than the pre-fix baseline of 103) against the widened lower
  bound AND the resolved upper range.
- **BR-5**: A Flutter-consumer smoke gate MUST run in CI (`flutter_consumer_smoke`
  job) and MUST be non-vacuous: it MUST fail on the pre-fix pubspec.

## Failing-test scenario (red)

Pre-fix tree, Flutter 3.47.2: `flutter pub get` in `example/` (and in a
synthesized core+flutter_test app) exits 1 with
`zuraffa from path is incompatible with flutter_test from sdk`.

## Non-behavior work

CI job wiring, gate script, spec/bug records.
