# Bug Fix: day-zero app shell launches into a zero-route GoRouter

- **Slug**: zero-route-gorouter-launch
- **Fixed**: 2026-09-16
- **Assessment**: ./assessment.md
- **Status**: applied
- **Branch**: `fix/zero-route-gorouter-launch` (isolated via `--branch`, rebased onto latest `master` 4e45c991)
- **TDD artifacts**: ./tdd/test-list.md, ./tdd/cycle-log.md, ./tdd/traceability.md, ./tdd/ui-ledger.md

## Summary

The generated `app_router.dart` (both `zfa setup` and `zfa app shell`, bare and skin-audit variants) now installs a day-zero `errorBuilder` and a runtime empty-table fallback `GoRoute(path: '/')` rendering a `ZfaDayZeroPlaceholder` Scaffold, so a fresh app launches with a placeholder instead of crashing with `no route for location: /`. The Flutter day-zero smoke test now also pumps the real shell and asserts the initial `/` resolves, making the regression class visible to `flutter test`.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/app_shell/builders/app_shell_builder.dart` | modified | `buildAppRouter({skinAudit, title})`: both emission branches emit `errorBuilder`, the `getAllRoutes().isEmpty` conditional fallback, and the `ZfaDayZeroPlaceholder` widget; material import added |
| `lib/src/commands/setup_command.dart` | modified | passes `title: appName` to `buildAppRouter` |
| `lib/src/commands/app_shell_command.dart` | modified | passes `title: title` to `buildAppRouter` |
| `lib/src/cli/writers/tdd/smoke_test_writer.dart` | modified | Flutter smoke-test flavor: keeps the container check, adds a `testWidgets` that pumps the name-derived shell and asserts `takeException()` is null after resolving `/` |
| `lib/tdd/zero-route-gorouter-launch/a{1..8}_subject.dart` | added | hand-implemented acceptance subjects (the designed hand-delta seam) wrapping the real builders |
| `test/tdd/zero-route-gorouter-launch/a{1..8}_test.dart` | added | A3–A8 scaffolded by `zfa tdd gen` then hand-stepped (real outcome assertions + `:hand` attestation); A1/A2/A7 hand-written (widget lane refused, see Deviations) |
| `test/plugins/app_shell/app_shell_builder_test.dart`, `app_shell_skin_audit_test.dart`, `test/skew/bug_1197_two_end_matrix_test.dart`, `test/cli/writers/tdd/*` | unchanged (verified green) | existing goldens already assert substrings compatible with the new emission (`routes: getAllRoutes()` matches inside the ternary); no weakening needed |
| `.specify/bugs/zero-route-gorouter-launch/*` | added | bug-dir workflow artifacts (issue, assessment, spec, tasks, tdd evidence) |

## Diff Highlights

Generated `app_router.dart` day zero (bare variant) — the crash surface becomes:

```dart
final GoRouter appRouter = GoRouter(
  routes: getAllRoutes().isEmpty
      ? [
          GoRoute(
            path: '/',
            builder: (context, state) => const ZfaDayZeroPlaceholder(),
          ),
        ]
      : getAllRoutes(),
  errorBuilder: (context, state) => const ZfaDayZeroPlaceholder(),
);
```

The fallback is runtime-side in this generated file: `zfa route`'s index regenerator (which rewrites or deletes `routing/index.dart`) can never clobber it, and the first `zfa route <Entity>` heals it automatically.

## Tests Added or Updated

Engine-certified (red-first via `zfa tdd verify-red`, green via `make --born-green`, evidence in `tdd/cycle-log.md`):

- `test/tdd/zero-route-gorouter-launch/a3_test.dart` — skin-audit router carries `errorBuilder` + fallback alongside `SkinRouteContractObserver` (live red→green proven: pre-fix emission failed `contains('errorBuilder')`)
- `test/tdd/zero-route-gorouter-launch/a4_test.dart` — the `routes:` ternary preserves a real route table; only an empty table swaps in the placeholder
- `test/tdd/zero-route-gorouter-launch/a5_test.dart` — fallback is runtime-side in `app_router.dart`; `route_builder.dart` (the index regenerator) never references the placeholder
- `test/tdd/zero-route-gorouter-launch/a6_test.dart` — pure-Dart smoke flavor stays router-free / Flutter-free
- `test/tdd/zero-route-gorouter-launch/a8_test.dart` — the new emission surface (errorBuilder, fallback, placeholder, hint, title threading)

Hand-proven (engine-un certifiable here, see Deviations):

- `test/tdd/zero-route-gorouter-launch/a1_test.dart` — bare variant installs `errorBuilder` + empty-table fallback + material import
- `test/tdd/zero-route-gorouter-launch/a2_test.dart` — day-zero `/` resolves via placeholder route + errorBuilder (first match + catch-all), not the GoException
- `test/tdd/zero-route-gorouter-launch/a7_test.dart` — Flutter smoke template keeps the container check and pumps the shell (`ZikZakTddApp`) asserting `takeException()` is null

## Local Verification

- `dart analyze` (all touched paths: app_shell, setup/app-shell commands, smoke writer, tdd feature dirs) → `No issues found!`
- `dart test test/plugins/app_shell/` → 89/89 pass (goldens compatible)
- `dart test test/skew/bug_1197_two_end_matrix_test.dart test/cli/writers/tdd/` → 71 pass
- `dart test test/tdd/zero-route-gorouter-launch/ test/cli/writers/tdd/` → 72 pass
- `dart format` on all touched files → clean
- Full fast tier via `tools/run_tests_chunked.sh` → see Gate Evidence in `tdd/cycle-log.md`
- Engine loop: baseline + per-behavior make steps ran scoped (`--baseline-scope test/tdd/zero-route-gorouter-launch`, issue #1374)

## Deviations from Assessment

1. **Loop driver's refactor gate is infeasible on this machine (documented repo gap).** `zfa tdd run` stopped honestly at `A3:refactor` — the refactor preflight/re-proof runs the FULL unscoped `dart test` (~1385 suites; the disk preflight already refused a full sweep at ~95 GB temp vs 87.5 GB free, and the sweep exceeds the 25-min step budget). This is the same wall the `cycle-log-phantom-sections` run recorded (25-min and 90-min kills, the #1333 doom loop) and its fix.md left as a follow-up: "`--baseline-scope` covers the baseline and `make` but not `refactor`". Resolution: the gate's SUBSTANCE was proven manually over the final tree (dart format + dart analyze + the sanctioned chunked fast suite), recorded as a hand gate-evidence entry in `tdd/cycle-log.md`. Suggested follow-up: give `tdd refactor` the issue-#1374 scoping flag.
2. **Widget-lane behaviors A1/A2/A7 could not be engine-certified.** `zfa tdd gen` refuses widget-lane behaviors without `zuraffa_ui` (issue #938) and this repo is pure Dart by design; without gen receipts, `make` refuses born-green certification. Their tests were hand-written in the acceptance shape and pass in the suite; the live pump evidence for A7 runs in the generated app (slow-tier `day_zero_smoke_gate_test`).
3. **Golden tests needed no edits.** The assessment predicted golden ripple; the existing app-shell/setup/skew assertions are substring-based and remained valid against the new emission, so they were verified rather than rewritten (no weakening).
4. **Spec edited after synthesis.** The first synthesized spec used AC-bullets; `zfa tdd plan --migrate-spec` required `Given/When/Then` scenarios (issue #990 marker + FR-012 grammar), so the spec was rewritten in the template grammar before planning.

## Follow-ups

- Give `zfa tdd refactor` a `--baseline-scope`-style flag so constrained machines can complete the loop driver (the #1333 economics root cause).
- Consider teaching the widget lane an emission-level fallback for pure-Dart repos so A1/A2/A7-class behaviors can certify without a Flutter host.
- Optionally ALSO teach `BootstrapRoutingIndexWriter` nothing — confirmed: the placeholder correctly lives in `app_router.dart`, not the index.
