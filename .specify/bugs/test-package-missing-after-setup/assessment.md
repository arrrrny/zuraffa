# Bug Assessment: test package still missing from dev_dependencies after zfa setup

- **Slug**: test-package-missing-after-setup
- **Created**: 2026-09-01T17:23:21Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/716
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

`zfa setup` does not add `test: ^1.0.0` to `dev_dependencies` in the generated `pubspec.yaml`, but generated tests under `test/tdd/*.dart` import `package:test/test.dart`. The result: fresh project cannot compile/run generated tests out of the box.

Workaround is `flutter pub add dev:test`.

See: https://github.com/arrrrny/zuraffa/issues/716

## Symptom

A fresh project created via `zfa setup` has `dev_dependencies` missing the `test` package. Running `flutter test test/tdd/a7_test.dart` fails with `Error: Could not resolve the package 'test' in 'package:test/test.dart'`.

## Reproduction

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy any spec (e.g. `specs/001-app-bootstrap/spec.md`)
4. `zfa tdd plan 001-app-bootstrap`
5. `zfa tdd gen A7 --feature=001-app-bootstrap`
6. `flutter test test/tdd/a7_test.dart` → compile error

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

Likely candidates: `lib/src/cli/commands/setup*.dart` or `lib/src/cli/writers/setup/*.dart` (the pubspec.yaml generation writer for fresh projects). Also: the tdd gen command's test template (`lib/src/cli/writers/tdd/`).

## Root Cause Hypothesis

`zfa setup`'s pubspec.yaml writer emits `flutter_test`, `flutter_lints`, `build_runner`, etc., but does not include `test: ^1.0.0` even though tdd-generated tests import `package:test/test.dart`. There is a mismatch between the test template (which uses `package:test`) and the pubspec template (which omits `test`).

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

Expected change: add `test: ^1.0.0` to the `dev_dependencies` template used by `zfa setup`. If `flutter_test` is already present (Flutter project), `test` may be redundant for Flutter-only projects — confirm whether the test templates are pure-Dart or Flutter-conventional.

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.
- Pure-Dart projects need `test`; Flutter projects can use `flutter_test` only, but if tdd test templates import `package:test`, the package is required for both.
- Bump range `^1.0.0` may need adjustment to match Dart SDK constraints.

## Open Questions

- [NEEDS CLARIFICATION: is this only for Flutter projects, or also pure-Dart? Confirm which tdd test templates use `package:test`.]
- [NEEDS CLARIFICATION: is there a related issue for `mocktail` (also already in the list) or any other tdd-required dev dep that was omitted?]
- [NEEDS CLARIFICATION: should the test package be version-pinned to a lower bound that matches the SDK constraint?]
