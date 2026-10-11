# TDD Verification — EPIC 1133 — the epic-closing lane

Generated fresh from the REAL runs of this session (2026-09-17/18 UTC).
No copied, stubbed, or back-dated content: every number below was
produced by a command executed in this session and is reproducible from
the commands listed.

## Session environment

- Toolchain: Dart 3.13.4 / Flutter 3.47.4 stable (the spec's floor:
  Dart 3.13+ / Flutter 3.47+).
- Working tree: master @ a9329746 (Merge PR #1694) on branch
  `feat/1133-tdd-loop-completeness`.
- The four sub-issue lanes (#964/#965/#966 + verify-red kind gate) were
  already merged (PRs #1216, #1209/#1047, #1362/#1048, #1219; kind trace
  #1396). This lane re-proves the epic's exit criteria on CURRENT master
  and closes the gap found on the way.

## The blocker found (and fixed) on current master

`zfa tdd verify --feature 004-login-ui` — pristine master:

```
gate: preflight_red
killed: 0 survived: 0 timed_out: 0 mutation_was_run: false
```

Root cause: the #1393 re-split moved U1 (FR-001, adaptive_layouts) into
the SKIN lane and deferred its green; the registry's 10-behavior
preflight therefore failed at `u1_test.dart`
(`UnimplementedError: subject_u1 not implemented`). Exit criterion 3 is
unreachable in that state — the referee refuses to audit a red scope.

Fix (this lane's code change): `subject_u1` greened to the declared
Skin Contract slots (`['mobile','ios','android','macos']`, declared
order), red→green cycle hash-chained in the feature's cycle-log.

## Exit criteria — PROVED (all four)

1. **AC-4 asserts a real route outcome** — PROVED by regeneration:
   `zfa tdd gen A4 --feature 004-login-ui --repair --widget-shell
   materialapp` (hermetic temp copy) emits
   `scenario-assertions: route-outcome("deal_list")` and
   `expect(observer.pushedNames, contains('deal_list'))` through the
   recording `NavigatorObserver` — a Text widget assertion appears
   nowhere in the emitted test. Diff vs the committed test: cosmetic
   only (dart-format line wrapping + a template comment rename
   ShadTheme→ZfaTheme). Committed A4 runs green
   (`00:00 +1: All tests passed!`).
2. **`findsNothing` for hides** — PROVED by regeneration: the same
   hermetic re-gen of A5 emits
   `scenario-assertions: absence("t.auth.error")` +
   `expect(find.text(t.auth.error), findsNothing)` (plus the
   `find.byWidget(view)` mount guard). Committed A5 runs green.
3. **All 5 behavior kinds traced** — PROVED by the full real audit:
   `zfa tdd verify --feature 004-login-ui` ran to completion THIS
   session (after the U1 green) and
   `example/specs/004-login-ui/tdd/verification.md` was regenerated
   fresh by that run:

   ```
   kinds: presence=2 absence=1 route-outcome=2 enabled-state=1 sequence=1
   ```

   A3 — presence; A4 — route-outcome; A5 — absence; A6 — enabled-state;
   A7 — presence, route-outcome, sequence. (W1/U1/A1/A2/U2 are the
   unit-lane rows without scenario-assertions headers — reported
   `not-traced`, honestly.)
4. **LocaleTests resolve keys; German pump at 130%+** — PROVED by real
   runs: the A3/A5/A7 tests boot the slang shell
   (`LocaleSettings.setLocaleRaw('en'/'de')`) and assert RESOLVED keys
   (`t.auth.signIn`, `t.auth.error`, `t.auth.working`); the `de`
   expansion pumps pass (`00:00 +1: All tests passed!` per file; the
   12-test full-scope run: `00:05 +12: All tests passed!`). Measured
   anchor expansion: auth.error 364%, auth.signIn 357%, auth.working
   318% of EN — comfortably past the 130% bar, layout holds
   (pumpAndSettle clean, no overflow exceptions).

## The audit (real numbers, this session)

- command: `zfa tdd verify --feature 004-login-ui` (cwd:
  `example/`, profile runner: flutter)
- runner_command: `dart run mutation_test` — exit 0, elapsed 590s
- gate: `fail_survived` — killed: 58, survived: 9, timed_out: 0
- mutation_score: 0.8657 (baseline before this lane: 48/8, 0.8571)
- restoration_verified: true — all 10 registered subjects restored
  (FR-021); spec_hash + per-subject hashes bound (bug #837)
- Survivors (honestly reported, remediation hints attached): the 8
  baseline W1 view gaps + A-lane equivalent-class mutants (login_view
  25/36/75/232/298/298, a4_subject 49, a7_subject 59 — unchanged files
  since the Sep-9 evidence) plus this lane's `u1_subject.dart:31`
  (slot-literal content mutant, unobservable by the type-level U1 test).
- The audit passed the 10-behavior preflight (bug #924) — every
  registered behavior green before any mutant ran.

## Commands (repro)

```bash
# preflight blocker (pristine master)
../scripts/zfa tdd verify --feature 004-login-ui   # gate: preflight_red

# the green + the full audit (this session)
flutter test test/tdd/004-login-ui/u1_test.dart    # +1 green
flutter test <10 registered test files>            # +12 green
../scripts/zfa tdd verify --feature 004-login-ui   # 58/9/0, kinds traced

# the regeneration proofs (hermetic temp copy)
zfa tdd gen A4 --feature 004-login-ui --repair --widget-shell materialapp
zfa tdd gen A5 --feature 004-login-ui --repair --widget-shell materialapp
zfa tdd gen A3 --feature 004-login-ui --repair --widget-shell materialapp --i18n-expansion de
```

## Not assessed / out of scope

- No changes to root-package `lib/` (the plugin code) in this lane —
  the four lanes' implementations are the merged PRs cited in the spec
  record. `dart analyze` on this lane's changed Dart file: clean;
  `dart format`: no diffs.
- Pre-existing suite state outside the 004-login-ui scope was not
  re-run (per the cloud-agent rule: only test what you changed).
