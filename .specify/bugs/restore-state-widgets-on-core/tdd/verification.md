# TDD Verification — BUG-1263 (restore state widgets on core)

- **Issue**: https://github.com/arrrrny/zuraffa/issues/1263
- **Feature/bug slug**: `restore-state-widgets-on-core`
- **Branch**: `fix/1263-restore-state-widgets-on-core`
- **Base**: `master` @ `d3679e0f` (Merge pull request #1266)
- **Date**: 2026-09-07
- **Toolchain**: Dart SDK 3.13.3 (stable) — meets the Dart 3.13+ requirement.
- **Engine detection (Step 0 of /speckit.tdd.verify)**: `zfa --version` absent
  from PATH, `.zfa.json` absent → `ZFA_MISSING` → **fallback LLM-guided audit
  per speckit.tdd.verify.md** (same path as the BUG-1173 precedent; the
  deterministic `zfa tdd verify` engine is not wired at the repo root).
- **Verdict**: **passed**

## 1. Fix under verification (remediation from the issue)

Re-landed the v6 state-widget sources at the deep paths `zuraffa_flutter`
re-exports (fix #14, `83fea58`), which core master deleted in `10e62deb`
(fix #1173):

- Restored `lib/src/state/widgets/{controlled_widget,signal_builder,fragment_builder}.dart`
  verbatim from `10e62deb^` (byte-identical pre-deletion contents).
- Restored `lib/src/state/widgets/widget_host.dart` (same commit) — it
  declares `ViewContext` / `ViewFragment` / `WidgetHost<C>`; the three
  contract libraries are written against it and it is part of the same
  host/fragment machinery ("it cannot compile once the three are gone",
  per the 10e62deb message — the converse holds too: they cannot compile
  without it).
- Minimal compile adaptation for the post-#1173 barrel: `signal_builder.dart`
  and `fragment_builder.dart` gained `import 'widget_host.dart';` (the same
  sibling import `controlled_widget.dart` already had). They previously
  reached `ViewFragment`/`ViewContext` through the barrel, and re-adding
  that barrel export is exactly what the purity guarantee forbids.
- `lib/zuraffa.dart` — **comment-only** update of the ownership rationale;
  **zero export directives changed** (verified: `git diff lib/zuraffa.dart`
  touches only the comment block). The widget libraries stay OUT of the
  barrel: the purity part of fix #1173 stands (deep-path imports are
  zuraffa_flutter's contract, not the public engine API).
- Added `test/regression/issue_1263_restore_state_widgets_test.dart` —
  fast-tier regression guard pinning the restored contract.
- Updated `test/regression/issue_1173_engine_purity_test.dart` to the
  revised ownership model (see §6) — its original clauses 1 and 3 encoded
  the file-deletion overreach that issue #1263 explicitly reverts
  ("deleting the files was overkill").
- Did NOT restore the 8 deleted `test/state/widgets/` suites: they were
  written against the old barrel-exported copies (they import
  `package:zuraffa/zuraffa.dart` and use `WidgetHost` from the barrel, which
  is now deliberately unexported). Re-landing them is beyond the minimal
  fix; the deep-path contract is pinned by the new guard instead.

## 2. Red evidence (before fix)

### 2.1 The regression guard fails with the issue's exact consumer error

```text
$ dart test test/regression/issue_1263_restore_state_widgets_test.dart   # pre-fix
00:00 +0: loading test/regression/issue_1263_restore_state_widgets_test.dart
00:00 +0 -1: loading test/regression/issue_1263_restore_state_widgets_test.dart [E]
  Failed to load "test/regression/issue_1263_restore_state_widgets_test.dart":
  test/regression/issue_1263_restore_state_widgets_test.dart:36:8: Error: Error when reading 'lib/src/state/widgets/controlled_widget.dart': No such file or directory
  test/regression/issue_1263_restore_state_widgets_test.dart:37:8: Error: Error when reading 'lib/src/state/widgets/fragment_builder.dart': No such file or directory
  test/regression/issue_1263_restore_state_widgets_test.dart:38:8: Error: Error when reading 'lib/src/state/widgets/signal_builder.dart': No such file or directory
  test/regression/issue_1263_restore_state_widgets_test.dart:39:8: Error: Error when reading 'lib/src/state/widgets/widget_host.dart': No such file or directory
```

The primary errors match the issue's reproduction byte-for-byte in error
class: `Error when reading '.../zuraffa/lib/src/state/widgets/controlled_widget.dart':
No such file or directory`. The guard's static imports ARE the
zuraffa_flutter contract, so "this file fails to compile" IS the downstream
failure — red for the RIGHT reason (missing deep paths, nothing else).

### 2.2 Root cause verified against the sibling repos

- zuraffa_flutter `83fea58` (`fix(#14)`, Sep 4) turns its three
  `lib/src/state/widgets/*.dart` files into pure re-export shims:
  `export 'package:zuraffa/src/state/widgets/<name>.dart';` (fetched from
  the remote at `83fea58` — shim comment "SYNC SHIM (engine/skin split
  session 2026-09-04)" verified verbatim).
- Core `10e62deb` (Sep 5, fix #1173) deleted exactly those paths.
- → both-HEAD pairing uncompilable; published pairing (pub.dev
  zuraffa_flutter 6.1.0, which still defines the widgets) unaffected.

## 3. Green evidence (after fix)

### 3.1 Regression guards green

```text
$ dart test test/regression/issue_1263_restore_state_widgets_test.dart \
            test/regression/issue_1173_engine_purity_test.dart
00:03 +5: All tests passed!
```

(4 tests in the new #1263 guard + 1 test in the revised #1173 guard.)

### 3.2 Affected functional area green (targeted, per cloud-agent rule)

```text
$ dart test test/state/
00:05 +68: All tests passed!
```

Including `tracks_2_3_2_4_golden_test.dart` (ControlledWidget +
FragmentBuilder template goldens) — the closest functional area to the
restored files. The full suite was deliberately NOT run (cloud-agent
constraint: it compiles a ~6.5 GB kernel cache; disk had ~7.9 GB free).
The changed-file test mapping (`git diff --name-only HEAD -- lib/ | sed
's|^lib/|test/|; s|\.dart$|_test\.dart|'`) yields no counterpart paths —
the old `test/state/widgets/` suites were deleted by 10e62deb — so the two
regression guards plus `test/state/` are the complete targeted surface.

### 3.3 Analyzer delta vs master baseline (changed files)

```text
$ dart analyze $(git diff --name-only HEAD -- '*.dart' | tr '\n' ' ')
Analyzing controlled_widget.dart, fragment_builder.dart, signal_builder.dart,
widget_host.dart, zuraffa.dart, issue_1173_engine_purity_test.dart,
issue_1263_restore_state_widgets_test.dart...
No issues found!
```

Repo baseline before the fix: `dart analyze lib` → 0 errors, 0 warnings,
104 pre-existing infos (lints, unchanged by this fix). Format gate on the
changed set: `dart format --set-exit-if-changed <changed files>` → 0 changed
(`dart format .` also run; the only files it touched beyond the changed set
were 3 pre-existing drifted spec-evidence files, which were reverted to keep
the PR minimal — master's format drift is not this bug).

### 3.4 Cross-repo compilation proof (downstream consumer, path dependency)

A minimal pure-Dart fixture package (`fixture_1263`) whose
`lib/src/state/widgets/*.dart` mirror the zuraffa_flutter fix #14 shim files
1:1 (same three `export 'package:zuraffa/src/state/widgets/<name>.dart';`
directives), path-depending on this fixed core checkout:

```text
$ dart pub get    # dependency_overrides: zuraffa -> path /home/z/my-project/zuraffa
Resolving dependencies... (resolved from path)
$ dart analyze
Analyzing fixture_1263...
No issues found!
$ dart test
00:00 +1: All tests passed!
```

The fixture's test consumes `ControlledWidget` / `SignalBuilder` /
`FragmentBuilder` through the shim re-exports (typed controller access,
ViewFragment subtyping) — the exact pairing the issue declares broken at
both HEADs now compiles and runs. (Flutter-side analysis of zuraffa_flutter
itself requires a Flutter SDK, unavailable on this agent; the pure-Dart
fixture + the verbatim shim-URI match in §2.2 prove the core-side contract.)

## 4. Mutation testing on the changed guards (fallback audit requirement)

Each mutant applied to the fixed tree, both guards re-run, then reverted.
All runs in this session:

| Mutant | Change | Guard result |
|---|---|---|
| control | no mutation | passed (5/5) |
| M1 | re-add `export 'src/state/widgets/controlled_widget.dart';` to the barrel (placed after the `signal_slice` export, syntactically valid) | **killed** — #1263 purity clause: `Expected: empty` / actual `[export ...]`; revised #1173 clause 1 fails too |
| M2 | delete restored `lib/src/state/widgets/signal_builder.dart` | **killed** — compile failure: `Error when reading 'lib/src/state/widgets/signal_builder.dart': No such file or directory` (the issue's exact error class) |
| M3 | declare `class SignalBuilder<T> {}` in `lib/src/core/sneaky.dart` (divergent copy outside the canonical dir) | **killed** — revised #1173 clause 2: `Actual: ['lib/src/core/sneaky.dart: SignalBuilder']` |

3/3 mutants killed — the guards lock both re-introduction paths (public
barrel export, divergent declaration) and the deletion path.

## 5. Test-smell rubric (guard tests)

- Deterministic: filesystem + syntax checks and constructible pure-Dart
  types; no network, no time, no RNG. The `_NeverCalledUseCase` fake is
  never invoked (`SignalSlice` is lazy; `FragmentBuilder` subscribes only on
  attach, which the guard never performs).
- Fast: both guards run in ~3 s together, default fast tier (no `slow` tag).
- No assertion roulette: every clause carries a `reason:` naming BUG-1263 /
  BUG-1173 and the rule it pins.
- Behavior-centric: asserts the consumer-visible contract (deep paths exist,
  re-exportable types resolve and construct, barrel surface unchanged), not
  implementation internals.

## 6. Acceptance criteria → status

| Criterion (from issue #1263 + hard constraints) | Status |
|---|---|
| RED reproduced for the right reason pre-fix (`No such file or directory` on the re-exported deep paths) | **PROVED** (§2.1) |
| GREEN: `lib/src/state/widgets/{controlled_widget,signal_builder,fragment_builder}.dart` restored and compiling | **PROVED** (§3.1, §3.3) |
| Files kept OUT of the `lib/zuraffa.dart` barrel (engine purity from fix #1173 stands; barrel diff is comment-only) | **PROVED** (§1, §3.3, §4 M1) |
| Both goals at once: deep paths exist for zuraffa_flutter's contract AND public API stays widget-free | **PROVED** (§3.4 + §4 M1/M3) |
| Cross-repo compilation proof | **PROVED** (§3.4, shim URIs matched verbatim in §2.2) |
| No new failures in the affected area (targeted suite only) | **PROVED** (§3.1, §3.2: 5/5 + 68/68) |
| One PR per bug, closes #1263 | satisfied by the accompanying PR |

## 7. Deviations / notes

- `.specify/bugs/restore-state-widgets-on-core/issue.md` / `assessment.md`
  were NOT present in the repo despite the task brief saying the records are
  committed (verified: 241 bug dirs, none matching; grep for the slug = no
  hits). The triage input used instead: the authoritative GitHub issue
  #1263 (fetched via API, open, created 2026-09-07) plus the task brief's
  root-cause/remediation section — they agree with each other and with the
  git history (`10e62deb`, `83fea58`).
- `specify init` was NOT re-run: `.specify/` is already initialized at the
  same speckit version (`1.0.5.dev0`, zed integration, script=sh,
  sequential numbering, agent skills on) and the standing warning forbids
  clobbering `.specify/templates|scripts`. `specify extension list` →
  `✓ TDD Extension (v1.1.2)` verified instead.
- The revised #1173 guard narrows the original "no colliding declarations
  anywhere in lib/" clause to "no declarations OUTSIDE the canonical
  `lib/src/state/widgets/`": under the restored fix #14 ownership model the
  widgets' single source of truth IS core's deep paths (issue #1263:
  deleting the files "was overkill"), and a same-named declaration anywhere
  else would be a divergent copy. The barrel-purity clause is unchanged.
- `test/regression/file_structure_test.dart` is `@Tags(['regression',
  'slow'])` and therefore excluded from the default fast tier by the repo's
  `dart_test.yaml` (pre-existing configuration, not a failure of this fix).
- `dart pub get` at the repo root resolves the root package cleanly; the
  nested `example/` Flutter app cannot resolve without a Flutter SDK and is
  out of scope for this pure-Dart fix (same `--no-example` convention
  documented by the BUG-1173 precedent).
