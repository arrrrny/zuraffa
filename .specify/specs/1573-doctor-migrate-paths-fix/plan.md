# Plan: 1573-doctor-migrate-paths-fix

- **Spec ID**: 1573-doctor-migrate-paths-fix
- **Created**: 2026-09-13

## Technical Context

- **The prescription sites** (positional → flag). Every site prints or
  returns the recovery command the operator is told to run:
  - `lib/src/core/proof/proof_chain_checker.dart:703` — `zfa proof chain`
    test-integrity import drift: `fix: 'zfa tdd migrate-paths $feature'`.
  - `lib/src/plugins/tdd/commands/doctor_command.dart` — four `migrate`
    prescriptions (single-owner foreign-owned :230, relocated-registry
    :377, path-form drift :484, import drift :612) plus the multi-owner
    ternary :230-231 (`'zfa tdd migrate-paths'` stays flag-less — it
    intentionally means "every registry").
  - `lib/src/plugins/tdd/commands/gen_command.dart:1039/:1108` — the two
    `foreignOwnerOf` verdicts build `migrateFix` into the refusal reason.
- **The scope defect**: `MigratePathsCommand._scanRegistries`
  (`migrate_paths_command.dart:871-887`). Flag form:
  `p.join(cwd, 'specs', featureFlag)` — a bare `p.join`, no resolver, so
  `.specify/bugs/<slug>` is unreachable and a plain bug slug silently
  names a nonexistent `specs/<slug>`. Sweep form: lists `specs/` only.
- **The family resolver** the fix routes through:
  `TddFeaturePaths` (`feature_path_resolver.dart`) — `resolve()` supports
  plain name → `specs/<name>`, `specs/<name>`, `.specify/bugs/<slug>`,
  absolute; `resolveWithPin()` adds the `.specify/feature.json`
  `feature_directory` fallback for a plain name whose legacy dir is
  absent; `pinned()` is null-safe on malformed/missing pins. Doctor
  already resolves through `resolveWithPin` (:131) — the doctor's
  `$feature` is `resolved.name` (the slug basename), so
  `--feature $feature` must re-resolve to the SAME directory from the
  slug alone.
- **The argument defect**: `MigratePathsCommand` declares only
  `--json/--dry-run/--feature/--project`. `_run()` never reads
  `argResults.rest`, so a positional slug is dropped on the floor and the
  no-flag sweep runs. The established loud-rejection idiom is
  `usageException(...)` (`args/command_runner.dart`) — CliRunner catches
  it, prints message + usage + `--> fix:` line, exit
  `ExitProtocol.usage` (2); `runCapturing` mirrors this for tests.
- **The drift-line defect**: doctor check 2e
  (`doctor_command.dart:464-481`) renders
  `_displayPath(cwd, p.normalize(record.testPath))` — for an absolute
  path inside the project root this is `p.relative`, i.e. the drift line
  claims "machine-absolute (...)" and prints a relative path. The fix
  prints the raw recorded string (`record.testPath`) — the exact bytes
  the registry carries.
- **Language/SDK**: Dart 3.13.3 stable, pure-Dart surface. Tests:
  `package:test` via `CliRunner(exitOnCompletion: false).runCapturing`,
  patterned on `test/plugins/tdd/commands/bug_1397_path_form_mismatch_test.dart`
  (`Directory.systemTemp` fixtures, `setUp`/`tearDown` deletion, the
  `verdict()` last-JSON-line and `fixLine()` helpers).
- **Test updates forced by the string change** (part of the prescription
  fix, not collateral): `bug_1397_path_form_mismatch_test.dart`
  (:221/:227/:302 + header comment :24) and
  `bug_874_doctor_cross_feature_adoption_test.dart`
  (:220/:270/:344 + header comment :19) assert the positional form.
  The #874 multi-owner guard (:294-296 `isNot(contains('migrate-paths $owner'))`)
  is unaffected — `--feature $owner` contains `migrate-paths --feature`,
  not `migrate-paths <owner>`.

## Architecture

```
 zfa tdd doctor .specify/bugs/<slug>          zfa proof chain / zfa tdd gen
        │                                              │
 resolveWithPin → dir=.specify/bugs/<slug>             │
 name=<slug>                                           │
        │                                              │
 check 2e: form drift (RAW recorded value printed)    │
        │                                              │
 fix: zfa tdd migrate-paths --feature <slug>  ◄────────╯  (same flag form)
        │
        ▼
 MigratePathsCommand._run
   ├─ rest.isNotEmpty → usageException (exit 2, names --feature)   [SC-3]
   └─ _scanRegistries(cwd, feature)
        ├─ flag form: TddFeaturePaths.resolveWithPin
        │    → dir has tdd/artifacts.json? use it
        │    → else plain-name probe: .specify/bugs/<slug>/tdd/artifacts.json
        │    → else legacy specs/<slug> (error path unchanged)     [SC-2]
        └─ sweep: specs/* THEN .specify/bugs/* (both sorted)       [SC-2]
        ▼
 registry-driven form rewrite (unchanged mechanics) → migrated=N
        ▼
 closing test: doctor → tokenize fix string → run it → migrated > 0  [SC-4]
```

## Risks

- **Pin ambiguity**: `resolveWithPin` for a plain name falls back to the
  pin only when `specs/<name>` is absent; the conventional
  `.specify/bugs/<name>` probe runs only when the resolved dir carries no
  registry — a specs feature and a bug feature with the same slug keep
  the legacy precedence (specs wins), matching doctor's own resolution.
- **Sweep widening**: adding `.specify/bugs/*` to the no-flag sweep
  changes `feature=all` runs. Acceptable and intended (the sweep's
  contract is "every feature registry"); the bug registries sort after
  `specs/` for deterministic output.
- **Real-repo drift**: this repo's own `.specify/bugs/` and `specs/`
  registries carry machine-absolute forms; the fix's sweep will want to
  rewrite them when contributors run it for real. Out of scope here — the
  PR only ships the corrected machinery and fixtures under
  `Directory.systemTemp`.
- `dart format` may reflow touched lines — run before commit.
