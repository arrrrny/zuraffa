# TDD Verification — Spec 1276 rename shadcn → skin

## Test-first evidence (RED recorded before implementation)

The migrated test files were committed to the working tree and run
BEFORE the lib/ rename landed. Red for a rename feature is a compile
and assertion red:

| Suite | RED observation |
|---|---|
| test/plugins/skin/skin_plugin_test.dart | loader failure: `SkinPlugin` undefined (`src/plugins/skin/skin_plugin.dart` did not exist) — `00:00 +0 -1: Some tests failed` |
| test/plugins/tdd/commands/bug_938_widget_skin_preflight_test.dart | 2 assertion failures: generated content still emitted `package:shadcn_ui/shadcn_ui.dart` and the old fix line (`00:00 +2 -2`) |
| test/commands/capability_receipt_test.dart (--preset=all) | receipt assertion failed: actual receipt still carried `plugin: shadcn` / label `zfa shadcn list Product` |
| test/commands/exit_code_sweep_1139_test.dart | loader failure: `SkinCommand` undefined |

Red runs were executed after `rm -rf .dart_tool/test/` kernel-cache
cleanup, per the cloud-agent protocol.

## Green evidence (after implementation)

Per-suite counts as observed (`dart test` default fast tier; slow-tagged
suites via `--preset=all`; NEVER the full suite):

| Suite | Result |
|---|---|
| test/plugins/skin/ (6 files: plugin, ui_command, registry, exporter, scaffolder, validator) | 42 passed, 0 failed |
| test/commands/exit_code_sweep_1139_test.dart + test/fixes/kill_list_fix_list_test.dart | 23 passed, 0 failed |
| bug_912_widget_shell_and_finders_test.dart + bug_938_widget_skin_preflight_test.dart + bug_938_skin_preflight_unit_test.dart | 19 passed, 0 failed |
| tdd/run_command_test.dart + tdd/services/step_runner_test.dart + skin_command_test.dart + skin_drive_command_test.dart | 34 passed, 0 failed |
| test/plugins/gym/gym_plugin_test.dart | 15 passed, 0 failed |
| test/plugins/tdd/subject_writer_test.dart | 5 passed, 0 failed |
| test/regression/issue_512_pure_dart_flutter_import_guard_test.dart (slow) | 10 passed, 0 failed |
| test/commands/capability_receipt_test.dart (slow) | 21 passed, 1 FAILED (see below) |

**Total observed: 169 passed / 1 failed.**

### Unrelated pre-existing failure (flagged, not fixed)

`capability_receipt_test.dart › observer create Watcher` fails with
`Expected: not contains '❌'` — the issue-#1149 observer-removal verdict
prints the honest refusal banner. Proven pre-existing: a pristine clone
of the base commit (before any spec-1276 change) reproduces the same
failure (`Some tests failed` on the identical test). The observer
plugin is outside spec 1276's scope; touching it here would mix
concerns.

## Acceptance-criteria coverage

| SC | Proof |
|---|---|
| SC-1 zero references | `rg -i "shadcn" lib/ test/ docs/` → no matches (exit 1) after migration; `.zread/wiki/drafts` also swept (10 refs migrated) |
| SC-2 certified emission | skin_plugin_test asserts the emitted imports are exactly material + `package:zuraffa_ui/zuraffa_ui.dart`, `ZfaCard`/`ZfaInput`/`ZfaButton`, and `isNot(contains('Shad'))`; kill-list + exit-sweep prove the layout grammar refuses |
| SC-3 capability unchanged | registry/exporter/scaffolder/validator suites (part of the 42) pass unchanged against `src/plugins/skin/` paths; capability id `ui.schema.export` asserted in ui_command_test |
| SC-4 receipt `plugin: skin` | capability_receipt_test `skin <layout> Product` passes (receipt envelope asserted) |
| SC-5 skin-named diagnostics | ui_command_test asserts `skin plugin not found`; --no-plugin diagnostics stay machine-parseable |
| SC-6 #938 preflight on zuraffa_ui | bug_938 integration (refuse/fix line/proceed/materialapp-opt-out) + bug_938 unit pins + bug_912 (ZuraffaApp shell + zuraffa_ui import) all green |
| SC-7 analyze/format | `dart analyze` over all 54 changed dart files: 0 errors, 0 warnings (1 pre-existing info outside changed lines); `dart format .` → 0 changed on re-run |
| SC-8 pure-Dart guard | issue_512 guard suite green (SkinBuilder refuses pure-Dart targets, emits Flutter widgets for Flutter flavor) |

## Test-strength / mutation evidence

Mutation testing was NOT run for this feature. The repo's
mutation-test.xml scopes mutations to the TDD plugin + writers and runs
the suite per mutant; on this cloud agent (disk ceiling, single-suite
protocol) that exceeds the budget. Honest compensating evidence: the
migration's red state was recorded against the REAL test binary, and
the green state was proven per-suite with the same assertions that
pinned the old vocabulary verbatim (string-level pins on receipts,
fix lines, skip reasons, imports, class names). A rename that missed a
site would fail the SC-1 grep gate or one of the verbatim string pins.

## Hygiene

Kernel caches (`rm -rf .dart_tool/test/`, `$TMPDIR/dart_test.kernel.*`)
were cleared after each RED/GREEN batch; `df -h .` stayed above 80%
free throughout; no fixtures or sandbox clones remain (the RED/GREEN
runs wrote only into `Directory.systemTemp` contexts that the tests
themselves dispose).
