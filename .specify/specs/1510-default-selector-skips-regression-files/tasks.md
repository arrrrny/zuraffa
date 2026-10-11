# 1510-default-selector-skips-regression-files — Tasks

- **Feature**: 1510-default-selector-skips-regression-files
- **Generated**: 2026-09-13 (MVP-first)
- **Loop**: configuration-level fix; behaviors are invocation-level (see
  `tdd/test-list.md`)

## MVP (the bug fix — smallest green set)

- [x] T1 (behaviour, SC-1) Tag `test/plugins/tdd/make_command_test.dart`
      `@Tags(['slow'])` → `@Tags(['regression', 'e2e'])`. Red: direct run
      exits 79 with 0 tests. Green: direct run selects and executes the
      file's 38 runnable behaviors — 33 pass, 5 fail with the
      byte-identical pre-existing failure set on master
      (`tdd/verification.md` §3). Clean-environment expectation: exit 0.
- [x] T2 (behaviour, SC-2) Tag `test/plugins/tdd/make_command_declared_071_test.dart`
      `@Tags(['slow'])` → `@Tags(['regression', 'e2e'])`. Red: direct run
      exits 79 with 0 tests. Green: direct run exits 0 with 1 test.

## Selector / lane integrity

- [x] T3 (non-behavioural, SC-3) `dart_test.yaml`: declare the `e2e:` tag
      in the `tags:` map and document it in the header comment.
- [x] T4 (non-behavioural, SC-3) `.github/workflows/ci.yaml#dart_core`:
      fast-lane selector `--exclude-tags flutter` →
      `--exclude-tags "flutter || e2e"` so the lane's selected set is
      unchanged.

## Verification & hygiene

- [x] T5 (behaviour, SC-4) Heavy lanes select the two files:
      `--preset=regression` and `--preset=all` both run them.
- [x] T6 (behaviour, SC-5) CI-lane composition guard: the exact CI command
      shape (`dart test <paths> --exclude-tags "flutter || e2e"`) still
      excludes the two files; the regression-tier integrity pin
      (`test/tier_integrity_test.dart`) still passes.
- [x] T7 (non-behavioural, SC-6) `dart analyze` on all changed files: no
      new issues; `dart format` clean on changed Dart files.
- [x] T8 (non-behavioural) Record red/green evidence in
      `tdd/verification.md`; kernel-cache housekeeping
      (`rm -rf .dart_tool/test/ && rm -f $TMPDIR/dart_test.kernel.*`)
      after every phase.
