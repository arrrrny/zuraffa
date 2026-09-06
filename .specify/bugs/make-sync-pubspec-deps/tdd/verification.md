feature: make-sync-pubspec-deps (spec #1190, slug make-sync-pubspec-deps)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: working tree at cced057b + spec/1190-make-sync-pubspec-deps
behaviors: 9
proven: 9
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 3/3 # scope: the three changed sites (scanner diff, doctor check, make post-pass); deliberate mutants, one at a time, all caught, restoration verified byte-exact via `git diff --stat` back to the fix diff
mutants_survived: 0
suite: new pins 23/23 (scanner 15 + doctor 5 + make 3), touched suites all green: doctor_checks_test 15/15, dependency_wirer_test 49/49, test/commands fast tier 262/262, make_command_test (slow) 17/17; analyze on changed files: 1 pre-existing master info (prefer_collection_literals, verified identical on stashed clean tree), 0 new findings; `dart format --set-exit-if-changed lib test` exit 0

# TDD Verification: spec #1190 — make syncs pubspec deps (or doctor catches the generated-imports ↔ pubspec mismatch)

**Verdict: PASS.** All nine new behavior pins landed as failing tests
BEFORE the fix (the three new suites fail at the pre-fix tree — compile
RED for the missing scanner + absent doctor check + absent make output),
the issue's exact canonical CLI shape is reproduced at the real
`zfa make` surface (pre-fix: silent success with undeclared imports;
post-fix: the exact `pub add` one-liner on completion), and the real
heal loop (`doctor FAIL → dart pub add → doctor PASS → 0
depend_on_referenced_packages findings`) was executed for real, not
simulated.

## Fix shape (issue option 2 — doctor detects + make prints on completion)

- `lib/src/core/dependencies/generated_import_scanner.dart` (new): the
  pure core — line/statement-anchored `package:` import extraction
  (handles conditional-import arms), pubspec declaration diff
  (dependencies + dev_dependencies; an override-only entry is NOT a
  declaration — the lint still fires), and the `pub add` one-liner
  builder (`flutter pub add` for Flutter projects, matching
  DependencyWirer's convention; SDK-provided packages excluded from the
  line because `pub add flutter` is the wrong remedy).
- `zfa make` post-pass: diffs the `.dart` files THIS RUN wrote
  (created/overwritten/updated only) against the target pubspec and
  prints the exact one-liner on completion; `--format json` reports it
  structurally as `missing_pubspec_deps` inside the same single JSON
  object (nothing appended after it — machine parsers stay valid).
  Skipped in dry-run/revert/plan modes.
- `zfa doctor` grew the `generated-imports` named check: scans `lib/` +
  `test/`, fails with the one-liner as `suggestedFix`, heals under
  `--fix` via the injectable process runner (hermetic in tests), skips
  cleanly on non-Dart roots, follows the artifacts-check "nothing to
  check is a pass" convention.

## Test-first evidence

| Behavior | Class | Evidence |
| --- | --- | --- |
| U-1190-M1 — the canonical make run (crud + vpc + state + di + test) prints `pubspec.yaml doesn't declare N package(s) the generated code imports: …` and a single `--> fix: dart pub add …` line naming the framework package when the fixture declares nothing | PROVEN | RED: suite failed pre-fix (scanner absent → compile RED; recorded `/tmp/tdd1190/red_make.txt`); post-fix 3/3 with the fix line asserted as one line containing `dart pub add` + `zuraffa` |
| U-1190-M2 — when every imported package is declared (zuraffa + test), the same run prints NO suggestion (no false positives on the all-declared path) | PROVEN | Pre-fix: unrunnable (compile RED); post-fix green with the negative pin `isNot(contains("pubspec.yaml doesn't declare"))` |
| U-1190-M3 — `--format json` carries the gap inside the SAME single JSON object (`missing_pubspec_deps.packages` + `suggested_fix`), keeping stdout parseable | PROVEN | Pre-fix compile RED; post-fix the balanced-JSON parse of the whole captured stdout succeeds and the fields are asserted |
| U-1190-D1 — the doctor check fails on undeclared imports with the exact one-liner as suggestedFix | PROVEN | RED: U-1190-D1 absent pre-fix (`red_doctor.txt`); post-fix `status==fail`, `suggestedFix=='dart pub add get_it'` |
| U-1190-D2 — all imported packages declared passes | PROVEN | Post-fix green (negative path) |
| U-1190-D3 — no Dart sources under lib/ or test/ passes cleanly (artifacts-check convention: nothing to diff is not a failure) | PROVEN | Post-fix green; initially pinned as `skipped`, corrected to `pass` to match the repo's convention before GREEN was declared |
| U-1190-D4 — `--fix` runs the exact one-liner via the injectable process runner and reports `fixed` | PROVEN | Recording runner asserts the invocation `dart pub add get_it` verbatim, status `fixed` |
| U-1190-D5 — Flutter projects get `flutter pub add` (not `dart pub add`) | PROVEN | Pubspec declares `flutter: sdk: flutter`; suggestedFix asserted exactly `flutter pub add get_it` |
| Scanner unit contract — plain + conditional-arm + export extraction, host-package exclusion, dart:/prose immunity, dedup, dev-dep counts as declared, override-only does NOT, SDK packages excluded from the one-liner (null when only SDK packages missing), exact `isSdkPackage` set | PROVEN | 15 unit pins, all red pre-fix (`red_scanner.txt`: `Undefined name 'GeneratedImportScanner'`), all green post-fix |

No existing test was weakened, skipped, renamed out of a filter's reach,
or excluded by config in this change. The only existing-test edit is the
U11 check-id set pin in `doctor_checks_test.dart`, which legitimately
grew by the new check id (`+1` line, `generated-imports`).

## Real-CLI healing loop (executed, not simulated)

Sandbox: temp target app, pubspec declares NOTHING, entity `Product`
pre-created (the exact first-run friction the issue describes).

1. `zfa make Product --preset=crud --methods=get,getList,create,update,delete --with=vpc --skin --state --di --test`
   → generation succeeds AND completion output carries
   `⚠️  pubspec.yaml doesn't declare 1 package(s) the generated code imports: zuraffa`
   + `--> fix: \`dart pub add zuraffa\`` (current master's generated
   surface imports only the framework directly — get_it is re-exported
   through zuraffa's DI output, and zuraffa_ui is no longer emitted by
   the skin lane on master, so the generic scanner reports what the
   generated tree ACTUALLY imports; the #1111-stage 28-infos shape is a
   superset case the same mechanism covers).
2. `zfa doctor` (pre-heal) → `[FAIL] generated-imports — generated code
   imports 1 package(s) pubspec.yaml doesn't declare: zuraffa` +
   `fix: dart pub add zuraffa`.
3. The printed one-liner's remediation applied for real:
   `dart pub add test zuraffa` → `Changed 101 dependencies!` (network,
   real resolution).
4. `zfa doctor` (post-heal) → `[PASS] generated-imports — all 1 imported
   package(s) declared in pubspec.yaml`.
5. `dart analyze` on the healed app → **0
   `depend_on_referenced_packages` findings**.

## Findings

| # | Severity | Finding | Evidence |
| --- | --- | --- | --- |
| 1 | LOW | The doctor `--fix` path spawns `dart/flutter pub add` without a `workingDirectory` parameter — matching the pre-existing `deps` check's process-runner signature; in real runs `_root == Directory.current` so it heals the right project, and hermetic tests inject a recording runner. A working-directory-aware runner type would be a wider refactor of the #793 runner contract, out of this spec's scope | `doctor_checks.dart` `ZfaProcessRunner` typedef unchanged; `_checkDeps` has the same shape |
| 2 | LOW | In a pure-Dart target, `--with=vpc` views legitimately import `package:flutter` (views are Flutter widgets, #420), so the make post-pass reports the SDK note (`flutter … declare with sdk: flutter`) instead of a bogus `pub add flutter` — honest output, but the deeper pure-Dart/view-lane tension is a separate pre-existing design fact, not a #1190 regression | `presenter_plugin.dart` view emission; SDK-package exclusion pins in the scanner suite |

## Mutation results

No mutation tool in the profile; deliberate-mutant sampling per the
rubric, one mutant at a time, restored exactly (byte-identical `cp` of
the pre-mutant file; `git diff --stat` re-verified back to the fix diff;
suites re-green after restore: 15 + 5 + 3).

| Mutant | Behavior | Survived | Judgment |
| --- | --- | --- | --- |
| `generated_import_scanner.dart` — `missingFromPubspec` reduced to a no-op (returns empty) | U-1190-D1/D5, M1, M3 | No | Caught by 3 doctor pins (2/5 → fail) and 2 make pins (1/3 → fail): the gap must come from the pubspec diff, not from nothing |
| `doctor_checks.dart` — `_checkGeneratedImports` returns pass unconditionally | U-1190-D1..D5 | No | Caught by 4 doctor pins (1/5 → fail): a permanently-green check cannot hide a real gap |
| `make_command.dart` — the post-pass gap forced to null before `_logSummary` | U-1190-M1, M3 | No | Caught by 2 make pins (1/3 → fail): completion output AND json payload must carry the gap |

## Rubric answers

1. **Tests first?** Yes — all three new suites were written and recorded
   failing at the pre-fix tree (compile RED for the missing scanner; the
   doctor/make pins could not pass without the new surfaces), then the
   implementation landed; the RED evidence is quoted above.
2. **Behavior asserted?** Yes — every pin asserts the observable CLI
   contract (completion lines, exact one-liners, JSON payload fields,
   doctor verdicts/status, recorded process invocations), not doubles or
   internals.
3. **Would they catch a bug?** Yes — 3/3 deliberate mutants caught,
   restoration verified byte-exact.
4. **Every requirement covered?** Yes — the issue's expected option 2 is
   implemented on both halves (doctor check + make completion output),
   the acceptance shape (analyzer-noise-free first run) is PROVED by the
   real healing loop ending in 0 `depend_on_referenced_packages`
   findings, and the option-1 alternative (auto-editing the user's
   pubspec) was consciously not taken: the printed one-liner keeps the
   user in control of their pubspec while still eliminating the manual
   detour.
5. **Worth keeping?** Yes — deterministic (no clocks, no network in the
   test tier — the networked `pub add` lives in the executed repro, not
   in CI), fast (the three suites complete in ~2s total), hermetic
   (temp fixtures disposed), and consistent with the neighboring #793
   doctor-check suite they join.
