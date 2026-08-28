# Bug Assessment: `zfa make` crashes with PathNotFoundException on invalid/removed CWD

- **Slug**: regression-321-make-cwd
- **Created**: 2026-08-22
- **Source**: pasted text (regression suite run, `dart test --preset=regression`)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

From the regression run (`dart test --preset=regression test/regression`), all 9
assertions in `test/regression/issue_321_no_first_field_id_fallback_enum_import_test.dart`
fail. `zfa make` invocations crash with:

```
PathNotFoundException: Getting current working directory failed, path = '' (OS Error: No such file or directory, errno = 2)
  #0      _Directory.current (dart:io/directory_impl.dart:46:7)
  #1      Directory.current (dart:io/directory.dart:136:25)
  #2      MakeCommand._findProjectRoot (package:zuraffa/src/commands/make_command.dart:77:25)
  #3      new MakeCommand (package:zuraffa/src/commands/make_command.dart:65:25)
  #4      CliRunner._ensureInitialized (package:zuraffa/src/cli/cli_runner.dart:81:24)
```

Exit code **255** where the tests expect `0` or `1`. Several assertions also
report `TimeoutException after 0:00:30.000000: Test timed out after 30 seconds`.

Failing assertions: Part A — id-less `zfa make ChatMessage` fails loudly and
exits 1; diagnostic names the entity + id requirement (merged #307/#322);
`--id-field` still fires the loud error for a truly id-less entity; `--no-entity`
skips the resolver; `@Zorphy(autoId:true)` generates String-typed ids cleanly.
Part B — generated presenter/controller/usecase/usecase-test files import the
enum barrel when the id field is an enum.

## Symptom

`zfa make` reads the current working directory unconditionally and throws
`PathNotFoundException` when the process CWD is an already-removed or empty
directory, instead of resolving the project root gracefully and either
succeeding or failing with a clear diagnostic (exit 1). The unhandled exception
produces exit 255 (and, in some paths, a 30s hang → test timeout).

## Reproduction

1. Start a Dart process whose CWD points at a directory that gets removed
   (e.g. `dart bin/zfa.dart make <Entity>` launched with `workingDirectory` set
   to a temp dir that is deleted while/after the command resolves the root).
2. Run any `zfa make` subcommand.
3. `MakeCommand._findProjectRoot()` calls `Directory.current.path` (line 77),
   which throws `PathNotFoundException: ... path = ''`.
4. `zfa make` exits 255 (or hangs → timeout) instead of a clean result.

In `issue_321`, each test's `setUp` creates `workspace` (a temp dir) and the
subprocess runs with `workingDirectory: workspace.path`; `tearDown` deletes
`workspace`. Under `dart test`'s process model the subprocess can observe a
removed CWD, triggering the throw. [NEEDS CLARIFICATION: exact isolation
boundary — whether it is the subprocess CWD or the test VM CWD — but the fix
below is robust either way.]

## Suspected Code Paths

- `lib/src/commands/make_command.dart:77` — `_findProjectRoot()` does
  `var dir = Directory.current.path;` with no guard; this is the exact throw
  site.
- `lib/src/commands/make_command.dart:84` — returns `Directory.current.path`
  as the fallback root; same fragility.
- `lib/src/core/project/project_root.dart:14` — the shared
  `ProjectRoot.find({startPath})` helper also does
  `final start = startPath ?? Directory.current.path;` and throws identically,
  so routing `make` through it would not by itself fix the crash.
- `lib/src/commands/make_command.dart:65` — `MakeCommand` constructor calls
  `_findProjectRoot()` before any option parsing, so the crash happens before a
  `--project-root` override (if one existed) could take effect.
- Systemic: many other commands read `Directory.current.path` directly
  (`app_shell_command.dart:116`, `config_command.dart:73`,
  `create_command.dart:84/123/215`, `doctor_command.dart:225`,
  `migrate_command.dart:46`, `module_command.dart:109`,
  `xray_mock_command.dart:68`, `xray_deck_command.dart:79/151`,
  `build_command.dart:363`, `build_yaml_guard.dart:39/55`), so the same crash
  can surface in those commands too.

## Root Cause Hypothesis

`zfa make` (and `ProjectRoot.find`) assume `Directory.current.path` is always
readable. Dart's `Directory.current` throws `PathNotFoundException` when the
process working directory is invalid — most commonly a directory that was
deleted out from under the process (tmp dir removed by a test, or a chdir into
a now-gone path in CI/containers). The unguarded read turns a recoverable,
environment-specific condition into a hard crash (exit 255) rather than a
controlled "could not find project root" diagnostic. Confidence: **high** for
the throw site and mechanism; **medium** for the precise trigger in this
particular test (isolated subprocess vs. shared test VM CWD).

## Proposed Remediation

**Preferred**: Make CWD resolution crash-proof and prefer an explicit root.

1. Add a single guarded CWD getter (e.g. in `project_root.dart`):
   ```dart
   static String _safeCwd() {
     try {
       final p = Directory.current.path;
       if (p.isNotEmpty) return p;
     } on FileSystemException {
       // CWD is removed/empty — fall through to fallbacks.
     }
     // Fallback chain: PWD env, then the script's own directory
     // (covers `dart run` / `dart compile` snapshots).
     return Platform.environment['PWD'] ??
         path.dirname(Platform.script.toFilePath());
   }
   ```
2. Use it in `ProjectRoot.find` (replace line 14) and have
   `MakeCommand._findProjectRoot` delegate to `ProjectRoot.find` (delete the
   custom method) so there is one hardened resolver.
3. Add a `--project-root` option to `MakeCommand` and thread
   `manager.projectRoot` from it; when provided, skip CWD resolution entirely.
   This also lets callers (and the regression test) be deterministic.

**Alternatives**:
- Minimal: wrap only `Directory.current.path` in `try/catch` and return a
  sensible default (e.g. `Platform.script` dir). Fixes the crash but keeps N
  duplicated reads across commands.
- Test-only: update `issue_321` to pass `--project-root workspace.path` and not
  delete the CWD temp dir until after the subprocess exits. Fixes the test but
  leaves the systemic fragility in `zfa`.

**Files likely to change**:
- `lib/src/core/project/project_root.dart` (harden `find`)
- `lib/src/commands/make_command.dart` (`_findProjectRoot` → `ProjectRoot.find` + `--project-root` option)
- Optionally the other commands listed under "Suspected Code Paths" for
  consistency.

**Tests to add or update**:
- Unit test `ProjectRoot.find` with an invalid/removed CWD (verify it does not
  throw and returns a sane fallback rather than `path = ''`).
- Update `test/regression/issue_321_..._test.dart` to pass `--project-root
  workspace.path` (deterministic, removes CWD dependence).

## Risks & Considerations

- Changing root resolution can shift detection in edge cases (e.g. nested
  packages); keep the "walk up for `pubspec.yaml`" behavior intact and cover it
  with tests.
- `Platform.script` fallback changes behavior for `dart compile`d snapshots vs
  `dart run`; validate both invocation paths.
- Hardening only `make` leaves `app_shell`/`config`/`create`/etc. exposed to the
  same crash — consider a follow-up sweep or a shared helper used everywhere.

## Open Questions

- [NEEDS CLARIFICATION]: Is the invalid CWD observed by the `zfa make`
  subprocess (its `workingDirectory`) or by the parent `dart test` VM? The fix
  is robust either way, but the answer scopes the test-side change.
