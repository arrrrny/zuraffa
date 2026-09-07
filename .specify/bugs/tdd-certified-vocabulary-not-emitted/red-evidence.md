# RED evidence — bug 1260 (tdd certified vocabulary not emitted)

Run: `dart test` (Dart 3.13.3, zuraffa @ d3679e0f, branch
fix/1260-tdd-certified-vocabulary-not-emitted), 2026-09-07.

## test/plugins/tdd/commands/bug_1260_zuraffaapp_widget_shell_test.dart

Result: 6 failed / 2 passed — every new-certified-vocabulary test failed
for the RIGHT reason:

- `parse("zuraffaapp") → the certified shell` — FAILED: parse falls back to
  `shadapp`, widgetName `ShadApp` ≠ `ZuraffaApp` (the certified shell is
  unreachable from the API).
- `the certified shell emits the zuraffa_ui barrel import` — FAILED: the
  writer has no zuraffaapp shell to render.
- `explicit --widget-shell zuraffaapp` — FAILED: `--widget-shell` allowed
  list is `['shadapp','materialapp']` → usage error, no artifacts.
- `skin-lane project: the certified shell is the DEFAULT` — FAILED: a
  pubspec declaring `zuraffa_ui` still defaults to the raw `ShadApp` shell.
- `.zfa.json tdd.widgetShell: "zuraffaapp"` — FAILED: config value falls
  back to `shadapp`.
- `project without zuraffa_ui: refuses BEFORE writing with --> fix: line` —
  FAILED: no machine-parseable certified-dependency refusal exists.
- PINS (green, pre-#1260 behavior): shadapp default on non-skin projects;
  materialapp opt-out.

## test/cli/writers/tdd/bug_1260_skin_dependency_patcher_test.dart

Result: 3 failed / 1 passed:

- `--skin adds zuraffa_ui under dependencies` — FAILED: `--skin` is an
  unknown option (`Could not find an option named "--skin"`); init patches
  only testing dev_dependencies.
- `--skin is idempotent` — FAILED (same root cause).
- `pure Dart: --skin is a loud misfire` — FAILED: no option exists, so no
  misfire naming the certified dependency either.
- PINS (green): without `--skin` the pubspec is untouched.

## test/plugins/app_shell/bug_1260_app_shell_zuraffa_app_test.dart

Result: 4 failed / 1 passed:

- `--zuraffa-app: my_app.dart mounts ZuraffaApp over the GoRouter tree` —
  FAILED: unknown option; emitted shell is `MaterialApp.router`.
- `project without zuraffa_ui: refused BEFORE writing, with the remedy` —
  FAILED: no option exists → no certified-dependency preflight.
- `--zuraffa-app --skin-audit composes` — FAILED (same root cause).
- `--zuraffa-app --xray composes` — FAILED (same root cause).
- PINS (green): without the flag, `MaterialApp.router` emission preserved.

## Verdict

Honest RED across all three pipeline surfaces from the assessment
(widget shell / init dependency / app shell). The failures reproduce the
four root-cause bullet points of issue #1260.
