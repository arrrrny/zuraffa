# TDD cycle log — bug 1260 (tdd certified vocabulary not emitted)

Branch: `fix/1260-tdd-certified-vocabulary-not-emitted` (from master @ d3679e0f)
Session date: 2026-09-07 · Toolchain: Dart 3.13.3 stable

## Cycle (red → green → refactor → verify)

### RED — commit f5b40905 (before any fix code existed)

New tests pinning the bug, all FAILING for the right reason at master:

- `test/plugins/tdd/commands/bug_1260_zuraffaapp_widget_shell_test.dart`
  6 failed / 2 pins passed — parse falls back to `shadapp`; `--widget-shell
  zuraffaapp` is a usage error; a skin-lane pubspec still defaults ShadApp;
  `.zfa.json tdd.widgetShell: "zuraffaapp"` ignored; no certified
  preflight refusal. Pins green: shadapp default (non-skin), materialapp.
- `test/cli/writers/tdd/bug_1260_skin_dependency_patcher_test.dart`
  3 failed / 1 pin passed — `--skin` unknown; no zuraffa_ui offer;
  no loud pure-Dart misfire. Pin green: pubspec untouched without --skin.
- `test/plugins/app_shell/bug_1260_app_shell_zuraffa_app_test.dart`
  4 failed / 1 pin passed — `--zuraffa-app` unknown; no certified shell
  emission; no composition; no preflight. Pin green: MaterialApp.router
  emission preserved.

Full red transcript: `red-evidence.md` (same folder).

### GREEN — commit f71879cd

Minimal pipeline-owned fix per the assessment (widget_scaffold,
behavior_test_writer, gen_command, zfa_config, init_command, new
pubspec_skin_dependency_patcher, app_shell_command, app_shell_builder).

All 17 new tests pass. Chunked regression sweep (kernel cache cleared
between chunks, the `tools/run_tests_chunked.sh` discipline) over every
affected folder: config 10, cli 204, app_shell 88, tdd/commands 343,
tdd/corpus_economics 53, tdd/models 81, tdd/theater 15, tdd/services 746,
tdd root 377, commands 306 — 2223 passing, 0 new failures, 0 skipped-new.
Disk kept healthy throughout (df checked between chunks; one kernel-cache
overflow at the tdd mega-chunk was cleaned immediately, the chunk was split
into subfolders, and the run resumed green).

### REFACTOR

Tooling only: `dart format .` (0 remaining diffs on all changed files —
the 3 pre-existing spec-1142 evidence files the formatter flags under
Dart 3.13.3's dart_style were REVERTED: committed historical evidence is
not reformatted by a bug fix). `dart analyze` on every changed file: clean.

### VERIFY

Real run, this session — see `verification.md` (gate verdict + mutation
kill table).
