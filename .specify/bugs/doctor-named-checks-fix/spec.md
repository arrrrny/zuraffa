# Spec — doctor named checks + auto-heal (#793)

Feature: named environment checks with auto-heal, JSON verdicts and a CI-able
exit code in `zfa doctor`.

## Functional requirements

- FR-1 `zfa doctor` runs five named checks in order: `deps`, `artifacts`,
  `baseline-cache`, `config`, `profile`, each producing a
  `DoctorCheckResult{ id, status: pass|fail|fixed|warn|skipped, detail,
  suggestedFix?, fixedItems[] }`.
- FR-2 `deps` fails when the project is a TDD project (`specs/` or
  `.specify/` present) and any of `mocktail`, `coverage`, `mutation_test` is
  missing from pubspec dev_dependencies; the suggested fix names the exact
  `dart pub add dev:…` command. When the `zuraffa` pin's major version is
  behind the CLI major, the check degrades to `warn` (never fail). Projects
  without pubspec.yaml are `skipped`.
- FR-3 `artifacts` fails when an entity source under
  `lib/src/domain/entities/` (excluding generated suffixes) lacks its sibling
  `.g.dart` or `.zorphy.dart`; the suggested fix is
  `dart run build_runner build --delete-conflicting-outputs`.
- FR-4 `baseline-cache` fails for any `specs/*/tdd/run-baseline.json` that is
  unreadable, schema-invalid (the WHY is stated: which field is missing or
  mistyped), or stale (any `test/**` file modified after `capturedAt`).
- FR-5 `config` fails when `.zfa.json` exists but is not valid JSON; warns
  when plugin keys are not builtin defaults; passes when absent.
- FR-6 `profile` fails when `specs/` exists but
  `.specify/memory/tdd-profile.md` is missing, suggesting `zfa tdd init`.
- FR-7 `--fix` heals the mechanical failures: missing dev-deps via
  `dart pub add`, rebuildable artifacts via build_runner, corrupt/stale
  baseline caches by deletion, missing profile via in-process idempotent
  `tdd init`. Checks whose remedy is not mechanical stay `fail` with their
  suggested fix printed. `--dry-run` previews would-fix lines and applies
  nothing.
- FR-8 `--format json` prints exactly one parseable JSON object
  `{"schema":"doctor.v1","checks":[…],"ok":<bool>}` with no surrounding
  prose and skips tooling/migration prose output.
- FR-9 Exit protocol: exit code 0 iff every executed check is ok
  (pass/fixed/warn/skipped), otherwise 1 — evaluated after the fix pass.
  `--migration-only` preserves today's behavior and skips the named checks.

## Acceptance criteria (issue)

- AC-1 A sandbox with a corrupted `run-baseline.json` + missing mocktail dep
  reports both; `--fix` heals both (dep added via runner, cache deleted).
- AC-2 A partial build_runner output (entity without `.g.dart`) is detected
  by the `artifacts` check with the build_runner command as suggested fix.

## Test list (U<p>: name — kills)

- U1 deps-missing-dev-deps-fail — FR-2, AC-1
- U2 deps-present-passes — FR-2
- U3 deps-fix-invokes-pub-add-and-reports-fixed — FR-7, AC-1
- U4 artifacts-entity-missing-g-dart-fails — FR-3, AC-2
- U5 artifacts-complete-or-absent-passes — FR-3
- U6 baseline-cache-corrupt-reports-reason-and-fix-deletes — FR-4, FR-7, AC-1
- U7 baseline-cache-stale-detects-test-tree-newer — FR-4, FR-7
- U8 baseline-cache-fresh-or-absent-passes — FR-4
- U9 config-malformed-fails-valid-passes-unknown-plugin-warns — FR-5
- U10 profile-missing-fails-and-suggests-tdd-init — FR-6
- U11 doctor-format-json-single-object — FR-8
- U12 doctor-exit-code-reflects-checks — FR-9
- U13 migration-only-skips-named-checks — FR-9
- U14 dry-run-previews-fixes-without-applying — FR-7
- U15 deps-zuraffa-pin-major-behind-warns — FR-2
