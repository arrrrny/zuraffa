# Test List — 1574-tdd-gen-relative-paths

Feature: `.specify/bugs/1574-tdd-gen-relative-paths`
Driver: `dart test test/plugins/tdd/commands/bug_1574_gen_relative_paths_test.dart`
Suite: `package:test` via `CliRunner` (house pattern of
`bug_1397_path_form_mismatch_test.dart` — real gen runs against a temp
project, no mocks).

| id | behavior | traces | kind | state |
|----|----------|--------|------|-------|
| A1 | fresh gen in the specs lane persists relative `test_path`/`subject_path` and a relative `runnable_test_name` first segment | issue §Proposed fix 1 | unit | DONE |
| A2 | fresh gen in the `.specify/bugs/<slug>` lane persists relative `test_path`/`subject_path` (the live leak at master) | issue §Evidence drift is live | unit | DONE |
| A3 | gen's emitted record (stdout `test_path:`/`subject_path:`/`runnable_test_name:`) carries the relative form in both lanes | issue §Proposed fix 1 | unit | DONE |
| A4 | re-gen of a behavior whose prior record is relative (the run driver's form) reuses without an ownership conflict in the `.specify/bugs/<slug>` lane | issue §Actual + acceptance 3 | unit | DONE |
| A5 | committed-registry census: every tracked `artifacts.json` records relative forms — no record's `test_path`/`subject_path` or `runnable_test_name` first segment starts with `/` after migration | issue §Proposed fix 3 | unit | DONE |

## Red evidence (pre-fix, recorded 2026-09-13)

- A1: RED — gen's record/verdict carries `/…` forms (persist stays relative
  only via the #1397 canonicalization net).
- A2: RED — persisted registry record is machine-absolute
  (`/tmp/.../test/tdd/...`), reproducing the issue.
- A3: RED — stdout record lines carry absolute forms.
- A4: RED — gen refuses with `path mismatch` ownership conflict against the
  relative prior record in the bug lane.
- A5: RED — 11 of 18 tracked registries carry absolute forms at master.
