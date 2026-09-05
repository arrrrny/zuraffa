# TDD Verification — BUG-1173 (engine purity / Flutter widget collision)

- **Feature/bug slug**: `1173-engine-purity-flutter-widget-collision`
- **Branch**: `fix/1173-engine-purity-flutter-widget-collision`
- **Base**: `master` @ `f2de0a2d`
- **Date**: 2026-09-05
- **Engine detection (Step 0 of /speckit.tdd.verify)**: `zfa --version` absent from PATH, `.zfa.json` absent → `ZFA_MISSING` → **fallback LLM-guided audit per speckit.tdd.verify.md** (deterministic `zfa tdd verify` engine not wired at repo root).
- **Verdict**: **passed**

## 1. Fix under verification (ownership decision: option 1, recommended)

Removed the re-introduced v6 state-widget copies from the pure-Dart core.
`zuraffa_flutter` is the canonical owner (spec 014 `pure-dart-core-split`):

- Deleted `lib/src/state/widgets/{controlled_widget,signal_builder,fragment_builder,widget_host}.dart`
  (`widget_host.dart` declares `WidgetHost<C>` over `ControlledWidget<C>` and
  would not compile once the three colliding classes were removed; it is part
  of the same host/fragment machinery, has no counterpart collision, and is
  orphaned without them).
- Removed the four barrel exports from `lib/zuraffa.dart` (fragment_builder,
  widget_host, controlled_widget, signal_builder) and replaced them with an
  ownership rationale comment referencing BUG-1173.
- Deleted `test/state/widgets/` (8 test files that exercised the removed
  core copies only; the canonical implementations live and are tested in
  `zuraffa_flutter`).
- Added `test/regression/issue_1173_engine_purity_test.dart` — fast-tier
  regression guard (syntactic; runs in the default `dart test` tier).

## 2. Red evidence (before fix)

### 2.1 Downstream repro — the bug's exact reproduction

Harness: `zuraffa_flutter` @ `3c888ea`, committed
`dependency_overrides: zuraffa -> git https://github.com/arrrrny/zuraffa.git`
(resolved to `6831bcef`, an ancestor of master `f2de0a2d`, containing the
identical colliding exports). The PR #16 workaround hides
(`hide ControlledWidget, SignalBuilder, FragmentBuilder` in the
`zuraffa_flutter` barrel and `test/state/widget_test.dart`) were **removed**
to model a downstream consumer without the workaround, per the bug's
repro contract.

```
$ dart analyze lib test        # cwd: zuraffa_flutter (pre-fix core)
18 errors, exit 3. First three:
error - lib/zuraffa_flutter.dart:57:8 - The name 'ControlledWidget' is defined
  in the libraries 'package:zuraffa/src/state/widgets/controlled_widget.dart'
  and 'package:zuraffa_flutter/src/state/widgets/controlled_widget.dart'. - ambiguous_export
error - lib/zuraffa_flutter.dart:60:8 - The name 'SignalBuilder' is defined in
  the libraries 'package:zuraffa/src/state/widgets/signal_builder.dart' and
  'package:zuraffa_flutter/src/state/widgets/signal_builder.dart'. - ambiguous_export
error - lib/zuraffa_flutter.dart:63:8 - The name 'FragmentBuilder' is defined
  in the libraries 'package:zuraffa/src/state/widgets/fragment_builder.dart'
  and 'package:zuraffa_flutter/src/state/widgets/fragment_builder.dart'. - ambiguous_export
(+15 derived ambiguous_import / extends_non_class / undefined errors in
 test/state/widget_test.dart — full log captured during the cycle.)
```

Matches the issue text byte-for-byte (`lib/zuraffa_flutter.dart:57:8`).

### 2.2 New regression guard (RED)

```
$ dart test test/regression/issue_1173_engine_purity_test.dart   # pre-fix
00:00 +0 -1: Some tests failed.
Expected: false
  Actual: <true>
lib/src/state/widgets/ was moved to zuraffa_flutter (spec 014). ...
```

## 3. Green evidence (after fix)

### 3.1 Downstream repro now clean — no workaround needed

```
$ flutter pub get   # override now: zuraffa -> path ../zuraffa (fixed)
! zuraffa 6.1.0 from path ../zuraffa (overridden)
$ dart analyze lib test        # cwd: zuraffa_flutter, PR #16 hides REMOVED
exit 0
5 issues found.                # 5x pre-existing deprecated_member_use info
0 ambiguous_export, 0 errors
```

### 3.2 Guard test green

```
$ dart test test/regression/issue_1173_engine_purity_test.dart
00:00 +1: All tests passed!
```

### 3.3 Core analyzer delta vs master baseline

```
                       errors  warnings  infos
master (git stash -u)      42         4    103
this branch                42         4    103
delta                       0         0      0
```

All 42 master errors are pre-existing `examples/` nested-package noise
(`uri_does_not_exist` in unresolved `examples/todo_tdd`, a consequence of the
repo's documented `--no-example` convention). Zero errors/warnings in
`lib/`, `test/`, `bin/` on this branch.

## 4. Mutation testing on the changed guard (fallback audit requirement)

Each mutant applied to the fixed tree, guard re-run, then reverted:

| Mutant | Change | Guard result |
|---|---|---|
| M1 | Re-add `export 'src/state/widgets/controlled_widget.dart';` to barrel | **killed** (failed as expected) |
| M2 | Re-create `lib/src/state/widgets/controlled_widget.dart` | **killed** (failed as expected) |
| M3 | Declare `class SignalBuilder<T> {}` in `lib/src/core/sneaky.dart` | **killed** (failed as expected) |
| control | no mutation | passed |

3/3 mutants killed — the guard is not a tautology and locks the ownership
decision against all three re-introduction paths.

## 5. Test-smell rubric (guard test)

- Deterministic: pure filesystem + syntax checks; no network, no time, no RNG.
- Fast: sub-second, default fast tier (no `slow` tag) — runs on every CI job.
- No assertion roulette: each of the three clauses carries a `reason` naming
  BUG-1173 and the ownership rule.
- Behavior-centric: asserts the exported surface (what downstream sees), not
  implementation internals.

## 6. Acceptance criteria → status

| Criterion (from bug record) | Status |
|---|---|
| RED: `ambiguous_export` reproduced downstream pre-fix | **PROVED** (§2.1) |
| GREEN: no collision after fix, without downstream `hide` workaround | **PROVED** (§3.1) |
| Core keeps only pure state/signal machinery (no widget classes/exports) | **PROVED** (§3.3 + guard clauses 1/2/3) |
| No two divergent implementations remain | **PROVED** — single implementation remains, in `zuraffa_flutter` (verified: its three files are the only definitions) |
| Regression guard in default CI tier, mutation-verified | **PROVED** (§4) |

## 7. Deviations / notes

- `specify init` was not re-run against the existing `.specify/` tree: the CLI
  refuses an existing project dir without `--force`, and a force-merge would
  re-scaffold stock templates over the committed, customized `.specify/`
  (the standing warning forbids clobbering `.specify/templates|scripts`). The
  end state `init` would produce is already committed at the same speckit
  version (`1.0.5.dev0`, zed integration; `specify extension list` →
  `✓ TDD Extension (v1.1.2)`), verified instead.
- `.specify/bugs/1173-*/issue.md` / `assessment.md` were not present in the
  repo (task anticipated "if exists"); the bug record shipped with the task
  brief was used as sole triage input.
- Root `dart pub get` requires `--no-example` on this toolchain (pub 3.13
  recurses into the unresolved nested `examples/` Flutter app; repo's own
  `scripts/rebuild.sh` documents the same convention).
