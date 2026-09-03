# Bug Issue: [TDD-132] widget-lane gen emits shadcn_ui imports the project may not declare — verify-red dies at compile on fresh projects

- **Slug**: widget-gen-shadcn-preflight-938
- **Fetched**: 2026-09-03
- **Issue**: 938
- **URL**: https://github.com/arrrrny/zuraffa/issues/938
- **State**: open
- **Severity**: high
- **Author**: arrrrny (Ahmet TOK)
- **Labels**: bug

## Body

`zfa tdd gen` (widget lane, bug #830/#912) emits tests that import
`package:shadcn_ui/shadcn_ui.dart` and boot `ShadApp` — but never checks the
project declares `shadcn_ui`. On a fresh `zfa setup` / `zfa-init` project (the
exact target of the 100% TDD machine), every widget-lane behavior dies at
`verify-red` with `compile-error` — the loop can never reach an honest RED.

### Repro

```
# fresh project via zfa-init / zfa setup (pubspec: flutter, zorphy_annotation, zuraffa_flutter — NO shadcn_ui)
$ zfa tdd plan 002-login    # widget-lane scenarios -> widget behaviors
$ zfa tdd run 002-login
[run] A1 gen -> ok
[run] A1 verify-red -> compile-error
zfa tdd run: step failed — behavior=A1 step=verify-red outcome=compile-error
run: feature=002-login result=stopped pending=10 red=0 green=0 done=0 stopped_at=A1:verify-red
```

Compile ground truth:

```
Error: Couldn't resolve the package 'shadcn_ui' in 'package:shadcn_ui/shadcn_ui.dart'.
test/tdd/002-login/a1_test.dart:21:8: Error: Not found: 'package:shadcn_ui/shadcn_ui.dart'
test/tdd/002-login/a1_test.dart:43:31: Error: Method not found: 'ShadApp'.
```

Live repro: `~/zik_zak_test` (specs/002-login, A1) — gen'd test
`test/tdd/002-login/a1_test.dart:21`.

### Root cause

The widget-pair generator (bug #912 self-hosting: "pumps it inside a ShadApp
shell") hardcodes the shadcn_ui import + `ShadApp` shell with no preflight
against the project's `pubspec.yaml`. `zuraffa_flutter` does not transitively
guarantee a resolvable `shadcn_ui` for the app project.

### Proposed fix

Errors-are-an-API (VISION §4): make the dependency explicit instead of silent.

- **`zfa tdd gen` (widget kind) preflight**: resolve the project pubspec; when
  `shadcn_ui` is absent, exit non-zero with a `--> fix:` line — e.g.
  `--> fix: flutter pub add shadcn_ui (widget-lane behaviors boot a ShadApp shell)`
  — before writing artifacts. Deterministic, no silent pubspec mutation.
- **And/or `zfa tdd init`**: ensure `shadcn_ui` is present when the baseline is
  created for a Flutter project (it already adds test/dev_dependencies; this is
  the widget-lane prerequisite).

Either way the acceptance test: on a shadcn_ui-less project, a widget-lane gen
stops with the named fix (exit non-zero, `--> fix:` line) instead of emitting a
test that can only die at compile.

### Workaround (used to unblock the 002-login experiment)

`flutter pub add shadcn_ui`, then re-run `zfa tdd run 002-login` (resumes from
run-state at A1).

### Related

- #922/#924 — baseline-failure handling in the runner (separate; here the
  stop-at-compile-error was honest and correct)
