# Bug Assessment: widget-lane gen emits shadcn_ui imports the project may not declare (#938)

- **Slug**: widget-gen-shadcn-preflight-938
- **Created**: 2026-09-03
- **Source**: https://github.com/arrrrny/zuraffa/issues/938
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

> `zfa tdd gen` (widget lane, bug #830/#912) emits tests that import
> `package:shadcn_ui/shadcn_ui.dart` and boot `ShadApp` — but never checks the
> project declares `shadcn_ui`. On a fresh `zfa setup` / `zfa-init` project,
> every widget-lane behavior dies at `verify-red` with `compile-error` — the
> loop can never reach an honest RED.

## Symptom

Widget-lane behaviors on a shadcn_ui-less project stop at
`verify-red -> compile-error` with:

```
Error: Couldn't resolve the package 'shadcn_ui' in 'package:shadcn_ui/shadcn_ui.dart'.
test/tdd/<feature>/<id>_test.dart:21:8: Error: Not found: 'package:shadcn_ui/shadcn_ui.dart'
test/tdd/<feature>/<id>_test.dart:43:31: Error: Method not found: 'ShadApp'.
```

The generated test is unloadable — the TDD machine cannot reach an honest RED
(an assertion-level failure), which is the loop's entry state.

## Reproduction

1. Fresh project (pubspec declares flutter, zorphy_annotation, zuraffa_flutter —
   NO shadcn_ui).
2. `zfa tdd plan` produces widget-lane behaviors (kind=widget rows).
3. `zfa tdd gen <id>` succeeds and writes
   `test/tdd/<feature>/<id>_test.dart` containing
   `import 'package:shadcn_ui/shadcn_ui.dart';` + `pumpWidget(ShadApp(...))`.
4. `zfa tdd run` → `A1 gen -> ok`, `A1 verify-red -> compile-error`, loop stops.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/behavior_test_writer.dart:266-271` —
  `_renderWidgetTest` emits
  `import 'package:shadcn_ui/shadcn_ui.dart';` whenever
  `widgetShell == WidgetAppShell.shadapp` (the DEFAULT per issue #912 defect 2).
- `lib/src/plugins/tdd/commands/gen_command.dart` — `_generate` has NO
  pubspec preflight: it validates behavior fields and ownership, then writes.
- `lib/src/plugins/tdd/services/widget_scaffold.dart:19-35` — `WidgetAppShell`
  documents shadapp as the default shell for zuraffa apps.

## Root Cause (confirmed by code read)

The #912 widget-pair generator made `ShadApp` the DEFAULT widget shell (with a
`--widget-shell materialapp` / `.zfa.json` `tdd.widgetShell` opt-out), but the
default lane assumes `shadcn_ui` is declared without verifying it. The default
`WidgetAppShell.shadapp` + missing dependency = an unloadable generated test.
`zuraffa_flutter` does not transitively guarantee a resolvable `shadcn_ui` for
the app project.

## Proposed Remediation

**Errors-are-an-API (VISION §4)** — make the dependency explicit instead of
silent:

1. `zfa tdd gen` (widget kind) preflight: resolve the project pubspec; when
   `shadcn_ui` is absent from `dependencies:`, exit non-zero with a
   machine-parseable `--> fix:` line —
   `--> fix: flutter pub add shadcn_ui (widget-lane behaviors boot a ShadApp shell)`
   — BEFORE any artifact is written. Deterministic, no silent pubspec mutation.
2. When the resolved shell is `materialapp` (explicit opt-out), no shadcn_ui
   import is emitted → preflight does not apply.
3. When no `pubspec.yaml` exists to resolve, gen keeps its pre-existing
   behavior (nothing changed for non-project fixture contexts).

**Alternatives** (issue's "and/or"): wire `zfa tdd init` to add shadcn_ui for
Flutter baselines — deferred; init already mutates pubspec for test/dev deps
and the gen preflight alone satisfies the acceptance test.

**Files likely to change**:

- `lib/src/plugins/tdd/services/widget_scaffold.dart` — preflight helper
  (pubspec dependency check + canonical fix line).
- `lib/src/plugins/tdd/commands/gen_command.dart` — preflight call before any
  write in `_generate`.
- `test/plugins/tdd/commands/bug_938_widget_shadcn_preflight_test.dart` —
  acceptance + unit tests.

**Tests to add or update**:

- shadcn-less project + widget gen → exit non-zero, `--> fix:` line on stdout,
  zero artifacts written, verdict JSON names the missing dependency.
- project declaring shadcn_ui + widget gen → unchanged success.
- `--widget-shell materialapp` on a shadcn-less project → unchanged success.
- no pubspec.yaml → unchanged success (fixture-context pin).
- unit: pubspec dependency probe (declared / absent / no pubspec / no
  dependencies section) + fix-line machine-parseability contract.

## Risks & Considerations

- The run flow (`zfa tdd run`) spawns `gen` as a subprocess: the refusal now
  stops the run at the `gen` step with the named fix — an EARLIER, honest stop
  than the compile-error the issue reports.
- Theme-kind behaviors also boot shadcn shells (issue #841 lane) — out of scope
  here (one PR per bug); the theme harness documents its prerequisites in the
  emitted header.
- Constraint honored: no silent pubspec mutation — the preflight only reads.
