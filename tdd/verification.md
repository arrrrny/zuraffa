# tdd.verify — Spec 1395 the day-zero app module declares its deps (fresh consumer analyzes clean after init)

- **Verified**: 2026-09-17 (22:28 UTC), this session, on
  `fix/1395-day-zero-module-deps` (working tree, pre-push), base `a9329746`
- **Toolchain**: Dart 3.13.3 (stable) / Flutter 3.47.4 on linux_x64 (the
  task's "Dart 3.13+ / Flutter 3.47+" floor; the repo pins `sdk: ^3.11.0`)
- **Scope**: `lib/src/commands/setup_command.dart` (the `_emitTddBaseline`
  day-zero pass), `lib/src/cli/writers/tdd/pubspec_app_dependencies_patcher.dart`
  (the `dryRun` seam), the new test files under
  `test/commands/` + `test/cli/writers/tdd/`, the extended
  `test/integration/day_zero_smoke_gate_test.dart`, and the spec artifacts
  under `.specify/specs/1395-day-zero-module-deps/`.

## Verdict: PASS

## 1. TDD discipline (red → green → verify)

Five behaviors were pinned in `tdd/test-list.md` BEFORE the fix (plus one
integration gate). The command-level red was observed against the stashed
(pre-fix) tree for exactly the reason the spec describes — the day-zero
baseline preview names `lib/app.dart` and declares none of the module's
runtime deps:

```
git stash push lib/src/commands/setup_command.dart \
               lib/src/cli/writers/tdd/pubspec_app_dependencies_patcher.dart
dart test test/commands/setup_1395_day_zero_app_deps_test.dart
→ 00:00 +0 -1: Some tests failed.
  Which: does not contain 'zuraffa_flutter: ^6.0.0'
  the generated lib/app.dart imports package:zuraffa_flutter/zuraffa_flutter.dart
  — the day-zero pass must declare it (spec 1395)
git stash pop
```

The writer-level rows (U-1395-b…e) use the new `dryRun` seam, which did not
exist pre-fix — the compile-error red is the honest first red for a NEW
seam (house convention, recorded for #1664 in this same directory).

## 2. Recorded runs (this session, actual)

```
# post-fix, fast tier
dart test test/commands/setup_1395_day_zero_app_deps_test.dart \
          test/cli/writers/tdd/pubspec_app_dependencies_patcher_1395_dryrun_test.dart
→ 00:00 +5: All tests passed!

# mapped + neighboring regression suites (writers, setup, baseline-init, #1653)
dart test test/commands/setup_1395_day_zero_app_deps_test.dart test/cli/writers/tdd/ \
          test/commands/setup_command_test.dart \
          test/plugins/tdd/services/baseline_init_sinks_test.dart \
          test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart
→ 00:15 +73: All tests passed!

# scoped analyze of every changed dart file
dart analyze lib/src/commands/setup_command.dart \
             lib/src/cli/writers/tdd/pubspec_app_dependencies_patcher.dart \
             test/commands/setup_1395_day_zero_app_deps_test.dart \
             test/cli/writers/tdd/pubspec_app_dependencies_patcher_1395_dryrun_test.dart \
             test/integration/day_zero_smoke_gate_test.dart
→ No issues found!

# integration tier — the REAL end-to-end gate (spawns `flutter create`,
# real `zfa setup`, `dart analyze lib`, `zfa tdd init`, `flutter test`)
dart test --preset=integration test/integration/day_zero_smoke_gate_test.dart
→ 01:40 +3: All tests passed!
  (2 pre-existing #626 gates stay green; I-1395-a green:
   both deps declared under dependencies:, `dart analyze lib` 0 errors,
   `zfa tdd init` re-run adds nothing)

# formatting
dart format .                                   → 3 files reformatted (all in this fix's diff)
dart format --set-exit-if-changed --output=none <changed files>
→ 0 changed, exit 0 — no formatting diffs remain
```

## 3. End-to-end fresh-consumer evidence (manual, this session)

### `zfa tdd init` path (the #1349 self-heal — re-proven at HEAD)

```
fresh `flutter create` consumer → `zfa tdd init`:
   ✓ lib/app.dart (created)
   ✓ pubspec.yaml dependencies (app module: added: zuraffa_flutter: ^6.0.0, get_it: ^9.2.1)
   ✓ pub resolution: flutter pub get --no-example (5.2s)
dart analyze  → No issues found!
flutter test  → All tests passed!
```

### `zfa setup` path (the #1395 gap this fix closes)

```
fresh `zfa setup green_consumer --no-git` (post-fix), step 6:
   ✓ lib/app.dart (created)
   ✓ pubspec.yaml dependencies (app module: added: get_it: ^9.2.1)   ← SAME pass, additive
   (the DependencyWirer had already declared zuraffa_flutter — no duplicate)
dart analyze lib → 0 errors (4 info lints: pre-existing style + the
                    di/index.dart `zuraffa` info — info severity does NOT
                    fail the #942 gate, issue #1035)
flutter test     → All tests passed!
```

Pre-fix control run (`zfa setup red_consumer --no-git` on base): step 6
wrote `lib/app.dart`; the only pubspec pass added `coverage: ^1.15.1` to
dev_dependencies — `get_it` was declared by NO pass, so the same-pass
contract was violated and any tree the DependencyWirer does not cover lands
in the reported 3-error misfire state.

### Acceptance composition (A2 phase 2, the #942 gate)

```
minimal engine-lane feature (spec 901-day-zero-composition in the sandbox
consumer): plan → 3 CORE behaviors routed
zfa tdd run 901-day-zero-composition
   baseline: 0 pre-existing failure(s)          ← the misfire reported 2
   A1 make → born-green, refactor → refactored (phase 2)
   U1 gen → verify-red → certified, make → refactor → clean (phase 2)
   run: result=complete  red=0  done=2
zfa build        (the exact command whose #942 gate refused pre-fix)
   ✅ Build completed successfully
   🔎 Running dart analyze on lib/... No issues found!
   ✅ dart analyze: no errors
```

The acceptance lane's honest stops observed on the way are DESIGNED
behavior, not the misfire: the acceptance guard-only test refuses
vacuous-green (issues #1488/#1512) and the entity-returning unit contract
is a hand-delta seam (issue #1308). Neither is a #942 refusal; both
resolve by the documented hand-step.

## 4. Success criteria — PROVED vs not

| criterion | status | evidence |
| --------- | ------ | -------- |
| deps added idempotently in the same pass as the module write | PROVED | U-1395-a…e green; fresh `zfa setup` prints the app-module deps line in step 6, additive (no duplicate when the wirer already declared the barrel) |
| fresh consumer tree `dart analyze` clean after init | PROVED | `zfa tdd init` consumer: `No issues found!`; `zfa setup` consumer: `dart analyze lib` 0 errors; I-1395-a green |
| re-run does not duplicate deps | PROVED | U-1395-e + I-1395-a (setup → `zfa tdd init` re-run, 1 match per dep) |
| acceptance composition path works (A2 no longer refuses) | PROVED | `zfa tdd run` → `result=complete` with 0 pre-existing failures; `zfa build` passes the #942 gate ("dart analyze: no errors") on the day-zero consumer tree |
| generated module's imports unchanged | PROVED | `AppModuleWriter.render` untouched in the diff |
| #942 guard semantics unchanged | PROVED | `build_command.dart` untouched in the diff |

## 5. Unrelated pre-existing findings (flagged, not fixed)

- Whole-repo `dart analyze` reports 208 pre-existing issues concentrated in
  unrelated sub-packages (`packages/zuraffa_graphql` — missing
  `gql`/`graphql` sources, `packages/zuraffa_observability`,
  `packages/zuraffa_storage` tests). Unrelated to this fix; scoped analyze
  of the changed files is clean.
- A fresh `zfa setup` tree carries 4 info-level lints, among them
  `lib/src/di/index.dart:9` `depend_on_referenced_packages` for
  `package:zuraffa` (the bootstrap DI barrel's import; `zuraffa` reaches
  Flutter trees transitively via `zuraffa_flutter`). Info severity does not
  fail the #942 gate (issue #1035). Declaring `zuraffa` on Flutter trees
  would be a separate dependency-declaration decision beyond this spec's
  minimal scope.
- `specify extension add tdd` returned a 404 downloading the release
  archive (`arrrrny/speckit-extensions` `tdd-v1.1.2`); the TDD Extension
  v1.1.2 is already bundled and enabled in the repo
  (`specify extension list` → "✓ TDD Extension"), so the loop used it.
