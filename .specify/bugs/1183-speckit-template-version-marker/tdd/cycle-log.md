# Cycle Log — 1183-speckit-template-version-marker

Branch: `fix/1183-speckit-template-version-marker` (base: master @ `42840d81`)
Toolchain: Dart SDK 3.13.3 (stable) — no Flutter (example/ needs it; not required here)

## Cycle 1 — RED (the bug, reproduced end to end) — 2026-09-06

- Read the committed machinery: `plan_command.dart` gate (#919), `spec_parser.dart`
  `parseTemplateVersion` / `knownTemplateVersions`, `spec_migrator.dart` (#990),
  `create-new-feature.sh` authoring path, `common.sh` `resolve_template_content`
  override stack. No `1183-*` bug records existed in-repo; the task bug context is
  the issue record (saved as `issue.md`).
- RED (CLI, real pipeline): authored `specs/1139-repro-1183/spec.md` via
  `create-new-feature.sh` (the code path `/speckit-specify` runs) — template
  copied verbatim, **0 `Template Version` matches** in the authored spec:

  ```text
  $ dart run bin/zfa.dart tdd plan 1139-repro-1183
  zfa tdd plan: contract drift — missing `**Template Version**` marker (spec: /home/z/my-project/zuraffa/specs/1139-repro-1183/spec.md). No test list was written.
    --> fix: run `zfa tdd plan --migrate-spec` to inject the latest template version marker into this spec (issue #990), or author the spec from the zuraffa spec template (zuraffa speckit extension) so it pins a known template version; re-run `zfa tdd plan`.
  exit code: 3
  ```

- RED (tests): added `test/plugins/tdd/bug_1183_speckit_template_version_marker_test.dart`
  (T1–T5, harness = real `CliRunner` on a temp project, same as bug_919). Pre-fix run:

  ```text
  00:00 +0 -5: Some tests failed.   # T1 T2 T3 T4 T5 all red
  ```

  T4/T5 failures carried the deterministic exit-3 signature from the real CLI.

## Cycle 2 — GREEN (the fix) — 2026-09-06

- Fix: `.specify/templates/spec-template.md` +2 lines — the treaty pin authored
  in the frontmatter position, byte-identical to what `SpecMigrator` inserts
  and what green specs carry:

  ```markdown
  # Feature Specification: [FEATURE NAME]

  **Template Version**: `zuraffa-1.0`
  ```

- GREEN (CLI, real pipeline): re-authored a feature via `create-new-feature.sh`
  → `specs/1140-green-1183/spec.md` now carries the marker (line 3); filled the
  placeholders the way the authoring agent does; first plan:

  ```text
  $ dart run bin/zfa.dart tdd plan 1140-green-1183
  zfa tdd plan: wrote File: '.../specs/1140-green-1183/tdd/test-list.md' with 1 acceptance + 1 unit behaviors (2 total).
  exit code: 0
  artifacts: tdd/test-list.md, tdd/traceability.md
  ```

  First-plan-just-works, no `--migrate-spec` detour. Both demo feature dirs
  removed after evidence capture (disk housekeeping; scratch receipts for the
  removed demo artifacts also removed from `.zfa/receipts/`).

- GREEN (tests):

  ```text
  00:00 +5: All tests passed!   # T1-T5, bug_1183_speckit_template_version_marker_test.dart
  ```

- Regression neighbors green: `issue_990_migrate_spec_test.dart` (the #919/#990
  gate contract unchanged — missing/unknown marker still exits 3),
  `bug_919_template_structures_test.dart` (40/40 with the 1183 + lanes + 1004 files),
  `spec_template_lanes_1000_test.dart`, `plan_skin_contract_1004_test.dart`.

## Cycle 3 — refactor

- Not required: the fix is a 2-line template change; no code refactoring applies.

## Verify

See `tdd/verification.md` (REAL runs only).
