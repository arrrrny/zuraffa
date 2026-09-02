# TDD Cycle Log — bug tdd-theme-harness (issue #841)

## Baseline

- Binary: pre-fix `fix/841-tdd-theme-harness` @ `b6afda42` (master HEAD)
- Suite: fast tier (default `dart test` exclusions), chunked runner
  `tools/run_tests_chunked.sh`
- Baseline status: run post-fix (gap recorded in verification.md — no
  pre-fix full-suite baseline was captured before the red cycle started)

## Cycle 1 — theme-kind behaviors produce the theme-harness pair

### RED (recorded 2026-09-03, pre-fix binary)

Test-first commits planned before the fix. Evidence classes:

1. **Reader pins** (`test/plugins/tdd/services/test_list_reader_test.dart`,
   group `theme kind`): compile/analysis failure on the pre-fix binary —

   ```
   error - test_list_reader_test.dart:506:41 - There's no constant named
   'theme' in 'BehaviorKind'. - undefined_enum_constant
   error - test_list_reader_test.dart:508:41 - ... undefined_enum_constant
   error - test_list_reader_test.dart:529:41 - ... undefined_enum_constant
   3 issues found.
   ```

   `dart test --plain-name "theme kind"` → loading failure (`Some tests
   failed` — the suite cannot even load the missing enum constant).

2. **Writer pins**
   (`test/plugins/tdd/services/theme_harness_test_writer_test.dart`):
   analysis failure on the pre-fix binary —

   ```
   error - Target of URI doesn't exist:
   'package:zuraffa/src/plugins/tdd/services/theme_harness_test_writer.dart'. - uri_does_not_exist
   error - Target of URI doesn't exist:
   'package:zuraffa/src/plugins/tdd/services/theme_harness_subject_writer.dart'. - uri_does_not_exist
   error - There's no constant named 'theme' in 'BehaviorKind'. - undefined_enum_constant
   error - The name 'ThemeHarnessTestWriter' isn't a class. - creation_with_non_type
   error - The name 'ThemeHarnessSubjectWriter' isn't a class. - creation_with_non_type
   ```

   (log: red phase, analyzer over the two new test files)

3. **Reproduction (behavioral red)** — the bug itself, reproduced through
   the public CLI: a project whose `specs/<feature>/tdd/test-list.md`
   declares a theme row cannot even express it on the pre-fix binary —
   `TestListReader` throws
   `test-list.md line N: unknown kind/section` (row malformed), and even
   with the row expressible, `GenCommand._generate` would dispatch to
   `BehaviorTestWriter`/`SubjectWriter`, emitting the plain-function pair
   whose assertion is `expect(result, isNot(isA<UnimplementedError>()))` —
   zero `ShadTheme`/`ThemeMode`/`matchesGoldenFile`/audit text
   (assessment.md → Reproduction). The pins in
   `test/plugins/tdd/commands/gen_command_theme_test.dart` fail against
   that emission.

Classification: compile/analysis red at the pin layer + behavioral red at
the CLI layer (the missing surface IS the bug — an absent generator cannot
fail at assertion time).

### GREEN (implemented 2026-09-03, same session)

Implementation, in the planned order:

1. `lib/src/plugins/tdd/models/behavior.dart` — `BehaviorKind.theme`
   added (doc-commented with the issue reference).
2. `lib/src/plugins/tdd/services/test_list_reader.dart` —
   `## Theme harness` section header → theme kind; `theme` accepted in
   the gen-legacy 6-column kind cell; format-law doc comment extended.
3. `lib/src/plugins/tdd/services/theme_harness_test_writer.dart` (NEW) —
   emits the four-proof harness (dual-ThemeMode ShadTheme assertions;
   AST-based hardcoded-color audit with constants whitelist; per-mode
   per-platform `matchesGoldenFile` baselines; fake-clock theme-switch
   latency against the certified tolerance), honest-red capture pattern,
   provenance headers.
4. `lib/src/plugins/tdd/services/theme_harness_subject_writer.dart`
   (NEW) — emits the subject contract (`ThemeHarnessSpec`,
   `themeHarnessSpec()`, `appShellFor(mode)` throwing stubs, and the
   `themeConstantsFiles` whitelist const).
5. `lib/src/plugins/tdd/commands/gen_command.dart` — `_writersFor(kind)`
   dispatch wired into BOTH the transactional write path and the
   staleness re-render mirror.

Green evidence (all re-run at HEAD after `dart format`):

- Reader + writer pins: `dart test test/plugins/tdd/services/
  test_list_reader_test.dart test/plugins/tdd/services/
  theme_harness_test_writer_test.dart` → `+37: All tests passed!`
- CLI integration (slow tag): `dart test
  test/plugins/tdd/commands/gen_command_theme_test.dart --preset=all`
  → `+2: All tests passed!`
- Fast-tier chunked suite (`tools/run_tests_chunked.sh` semantics, run
  chunk-by-chunk with the runner's flags `--exclude-tags flutter`):
  62 PASS + 5 SKIP (slow-tier-only chunks) = 67/67 chunks done. One
  transient flake recorded mid-run
  (`corpus_status_command_test.dart U34`, exit on first attempt, all
  green on immediate re-run — temp-dir race in the corpus fixture, a
  pre-existing flake class; the fix touches no corpus code).
- `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/` →
  `No issues found!` (full-repo analyze: 47 pre-existing
  examples/todo_tdd issues vs 48 on the pre-fix stash — none in the
  touched tree; the delta is analyzer cache noise, both runs list only
  the standalone example package).
- Emitted-text syntax proof: both generated files parse with the
  analyzer (`parseString`, SYNTACTIC_ERROR filter) — zero syntax
  errors; the harness text compiles as far as a Flutter-less host can
  prove (imports of flutter/shadcn/analyzer resolve in the target).
- `dart format` — the 4 touched files formatted;
  `dart format --set-exit-if-changed --output=none lib/src/plugins/tdd/
  test/plugins/tdd/` → 0 changed. One PRE-EXISTING drift exists at
  `examples/mcp_demo/lib/src/mcp/tools.dart` on master (not this bug's
  file; left untouched — minimal change).
