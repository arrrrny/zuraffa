# Bug Fix: `zfa tdd run` and the run/doctor/verify family now resolve bug directories

- **Slug**: 1471-tdd-run-bug-dir-resolution
- **Fixed**: 2026-09-10
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: none — the fix was applied through the classic flow; see **Deviations from Assessment** for why the bug's own TDD loop could not bootstrap it.

## Summary

Completed the issue #1182 migration that had previously taught only `tdd plan` the
`.specify/bugs/<slug>` shape. `TddFeaturePaths` is now the single resolver for the whole
run family: every command resolves its `<feature>` reference through it, the parent hands
its children the canonical `ResolvedFeatureDir.ref`, and `RunDriverCore.drive` resolves the
reference itself instead of joining `specs/<feature>`. As a result the documented bug TDD
loop (`bug.fix` → `tdd.plan` → `tdd.run` → `tdd.verify`) can complete, the bare slug honors
the `.specify/feature.json` pin, and artifacts land beside the resolved spec rather than
under a fabricated `specs/<slug>`. Plain-name resolution is byte-identical to before.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/services/feature_path_resolver.dart` | modified | `ResolvedFeatureDir` gains `ref` (the canonical reference a parent hands its children). `resolve` returns it for all four documented shapes. New `isSupportedRef` gate, `pinned` (reads `.specify/feature.json` → `feature_directory`), and `resolveWithPin`. A trailing separator is refused on the raw reference (`p.normalize` would otherwise collapse `specs/` to `specs` and make the guard unreachable); the pin value is normalized before validation so a pin written with a trailing slash still resolves. |
| `lib/src/plugins/tdd/commands/run_command.dart` | modified | Resolves via `resolveWithPin`; carries `featureDir` + `featureRef` to the driver, journals and receipts instead of seven `p.join(projectRoot, 'specs', feature)` sites. |
| `lib/src/plugins/tdd/commands/run_driver_core.dart` | modified | `drive` takes `featureRef` and resolves internally; hands `resolved.ref` to `StepRunner.run`. `_finish` gains `projectRoot`; `_recordStepFailure` takes `featureDir`; `_handStepViolationFor` takes an explicit `projectRoot`, replacing the walk that keyed on a parent literally named `specs`. `validateFeatureSegment` accepts supported path references. |
| `lib/src/plugins/tdd/commands/run_engine_command.dart` | modified | Same resolve-and-thread treatment as `run`. |
| `lib/src/plugins/tdd/commands/run_skin_command.dart` | modified | Same. |
| `lib/src/plugins/tdd/commands/doctor_command.dart` | modified | `resolveWithPin`; banners name the relative **resolved** directory; child hints use `resolved.ref`. |
| `lib/src/plugins/tdd/commands/verify_command.dart` | modified | `resolveWithPin`; `featureDir` comes from the resolver; validator relaxed to `isSupportedRef`. |
| `lib/src/plugins/tdd/commands/gen_command.dart` | modified | Resolves scope and threads `(dir, ref, name)`; `featureName` from `.name`, `featureRef` from `.ref`. `testListScopeRejection` exempts `.specify/bugs/<slug>` from the single-segment gate while keeping the containment boundary at the project root, so the #1272 traversal guard is unchanged. Audit-log and child-hint paths use the resolved forms; passes `featureDir` to `declaredSignatureFor`. |
| `lib/src/plugins/tdd/commands/make_command.dart` | modified | Same pattern; the summary uses the resolved label and the spawned `zfa tdd view --feature` receives the canonical ref; the registry scan uses `resolved.dir`. |
| `lib/src/plugins/tdd/commands/verify_red_command.dart` | modified | Registry scan and planned-in-test-list checks resolve through the shared resolver; user-facing paths use the resolved directory. |
| `lib/src/plugins/tdd/commands/refactor_command.dart` | modified | A `featureDir` local replaces every `p.join(cwd, 'specs', featureName)`; `CycleLog(featureDir)`. |
| `lib/src/plugins/tdd/commands/view_command.dart` | modified | `_RegistryEntry`/`_Resolved` carry the real feature directory; the `--feature` branch resolves through `TddFeaturePaths`; both `specs/<featureName>` path rebuilds use `resolved.featureDir`. |
| `lib/src/plugins/tdd/services/declared_routing.dart` | modified | `declaredSignatureFor` accepts an optional `featureDir`; the legacy `specs/<featureName>` join remains as the fallback for callers without a resolved directory. |
| `lib/src/plugins/tdd/services/cycle_log_terminal_receipt.dart` | modified | Takes a `required String featureDir` instead of joining `specs/<feature>` internally. |
| `lib/src/plugins/tdd/services/step_runner.dart` | modified | Parameter renamed `feature` → `featureRef` in the docstring (the argv flag is unchanged). |
| `test/plugins/tdd/commands/run_command_bug_1471_test.dart` | added | New regression suite, 18 tests. |

## Diff Highlights

The resolver's gate — the change that turns the reported usage error into accepted input
while keeping every refusal that existed before:

```dart
// isSupportedRef
if (p.isAbsolute(featureRef)) return true;
if (_hasDotDotSegment(featureRef)) return false;
// Checked on the RAW reference: p.normalize collapses `specs/` to `specs`.
if (featureRef.endsWith('/') || featureRef.endsWith(r'\')) return false;
final unified = p.normalize(featureRef).replaceAll(r'\', '/');
return unified.startsWith('specs/') || unified.startsWith('.specify/bugs/');
```

The pin fallback — ambient state can only ever *reinforce* the caller, never hijack it:

```dart
// resolveWithPin: the pin is consulted ONLY for a plain name whose legacy
// specs/<name> does not exist, and only when the pinned basename matches.
if (!isPlain) return legacy;
if (Directory(legacy.dir).existsSync()) return legacy;
final pinnedDir = pinned(projectRoot: projectRoot);
if (pinnedDir != null && pinnedDir.name == featureRef) return pinnedDir;
```

## Tests Added or Updated

`test/plugins/tdd/commands/run_command_bug_1471_test.dart` — 18 tests:

- Resolver unit: a bug-directory reference resolves to `.specify/bugs/<slug>` and keeps the
  slug as its name; the canonical `ref` round-trips to the same dir and name; a plain name
  still resolves `specs/<name>`; `isSupportedRef` accepts the four documented shapes and
  still refuses traversal, `.`, `..`, empty, and the trailing-separator shapes.
- Pin: absent pin → miss; a valid pin resolves through the resolver; a malformed pin
  degrades to a miss, never a redirect; a bare slug resolves to the pinned bug directory; an
  existing `specs/<slug>` wins over the pin; a pin naming a *different* feature never
  hijacks the slug; an explicit path always beats ambient state.
- CLI end-to-end `zfa tdd run`: an explicit `.specify/bugs/<slug>` reference is no longer a
  usage error; a bare slug honors the pin; the bug directory's own test list is the one
  read; a plain feature name still resolves `specs/<name>`.
- Doctor/verify: `doctor` names the bug directory it actually used; `verify` accepts the
  bug-directory shape in `--feature`.

## Local Verification

- `dart analyze lib` → **0 errors, 0 warnings** (112 pre-existing `info` lints, all in
  generated `lib/tdd/**` files).
- `dart format lib test` → clean (`Formatted 2541 files (2 changed)`; both changed files are
  this fix's own).
- `dart test test/plugins/tdd/commands/run_command_bug_1471_test.dart` → **18/18 pass**.
- `dart test --preset=all test/plugins/tdd/issue_1308_vacuous_guard_remedy_driver_test.dart`
  → **4/4 pass**. This is the strongest end-to-end evidence: it drives the real
  `zfa tdd run` through `CliRunner` into the real `RunDriverCore`, so it exercises the
  changed `drive(featureRef:)` signature and the routing/hand-step paths.
- `dart test --preset=all test/plugins/tdd/bug_1272_gen_project_scoped_test_list_test.dart`
  → **12/12 pass**; the `testListScopeRejection` traversal guard that `gen_command.dart`
  touches is intact.
- `dart test test/plugins/tdd/run_command_path_format_test.dart test/plugins/tdd/commands/plan_command_bug_1182_test.dart`
  → **16/16 pass**; `specs/<f>`, bare names, `specs/`, `..` and `specs/../foo` all keep their
  documented behavior, and the #1182 resolver contracts are unchanged.
- `dart test --preset=all test/plugins/tdd/verify_red_subdirectory_test.dart` → **4/4 pass**.
- `dart test --preset=all test/plugins/tdd/refactor_command_test.dart` → **14/14 pass**.
- `dart test --preset=all test/plugins/tdd/make_command_test.dart` → 33 pass / 5 fail;
  `verify_red_command_test.dart` → 18 pass / 1 fail; `tdd_command_smoke_test.dart` → 7 pass
  / 1 fail. See **Pre-existing failures** below.
- Manual check: a temp project pinned to `.specify/bugs/<slug>` with a registry record —
  `zfa tdd view` previously reported `unknown behavior id`; it now scaffolds the subject and
  writes its provenance ledger under the bug directory, with nothing created under `specs/`.

### Pre-existing failures

The seven failures in the three slow suites above are **not caused by this change**. Each
was re-run with the *entire* change set stashed (`git stash push -- lib/src/plugins/tdd/`,
tree at HEAD, then restored); the failures reproduce identically at HEAD.

Also corrected here: an earlier intermediate report claimed `make_command_test`,
`verify_red_command_test` and `tdd_command_smoke_test` were failing *as fast-tier* suites at
`test/plugins/tdd/commands/…`. Those paths do not exist — `dart test` reports that as
`Failed to load … Does not exist`, which reads like an assertion failure but is not one. The
real files live directly under `test/plugins/tdd/` and are `@Tags(['slow'])`.

Separately, `test/plugins/tdd/commands/view_command_test.dart` U-V3 fails on macOS **at
HEAD**, independent of this change. Cause: when the recorded subject file does not exist,
`resolveSymbolicLinks` throws and the code falls back to the *un-canonicalized* path, so a
`/var/…` subject is compared against the canonical `/private/var/…` root and is reported as
"points outside the project root" instead of "missing subject file". It passes on Linux CI.
See **Follow-ups**.

## Deviations from Assessment

1. **The fix was applied directly, not through the TDD red-green loop**, even though
   `bug-config.yml` sets `tdd_enabled: true`. The assessment's own subject is that
   `zfa tdd run` cannot operate on a bug directory, and `bug.fix`'s TDD mode drives the fix
   *through* `tdd.run`. Bootstrapping this fix through the loop that the bug breaks is not
   possible; the classic flow was used instead. `.specify/feature.json` was **not** repointed
   at `BUG_DIR`, so no consumer of the current feature is disturbed.
2. **Scope expanded beyond the assessment's file list.** The assessment named run /
   run-engine / run-skin / doctor / verify. The run driver spawns children with
   `--feature <reference>`, so `gen`, `make`, `verify-red` and `refactor` — and the
   `view` command that `make` spawns — were converted too, along with
   `declared_routing.dart` and `cycle_log_terminal_receipt.dart`. Leaving them hardcoded
   would have re-broken the same loop one step later, which is the same defect class.
3. **`declaredSignatureFor` gained an optional `featureDir`** rather than a required
   parameter swap, so callers that have no resolved directory keep working unchanged.
4. **The assessment's `featureDirectoryPin(projectRoot)` became two methods** — `pinned()`
   for the raw read and `resolveWithPin()` for the fallback rule — because the pin must be
   consulted only for a plain name whose legacy directory is absent, and only when the
   pinned basename matches. A single "read the pin" helper could not express that rule.
5. **The trailing-separator refusal in `isSupportedRef`** was not in the assessment; it was
   discovered while making the new suite pass against
   `run_command_path_format_test.dart`'s pre-existing "bare `specs/`" contract.

## Follow-ups

- `view_command_test.dart` U-V3 (macOS-only, pre-existing): the symlink canonicalization
  added for `/var` → `/private/var` is defeated by its own fallback, which compares the
  un-canonicalized path when the subject file is absent. `compose_command.dart:240`,
  `wire_command.dart:218` and `func_command.dart:181` carry the same pattern.
- `func_command.dart` still builds `specs/<featureFlag>` from its own `_Resolved`, which
  carries only a name — so `zfa tdd func` mis-resolves a bug feature. It is not on the run
  loop's path, and fixing it needs `_scanRegistries`/`_Resolved` converted the way
  `view_command.dart` now is.
- `generation_planner.dart` emits `--feature <record.feature>` where the record's `feature`
  is a basename (`artifact_registry.dart:365`). In the pinned bug flow this resolves via the
  pin, but a bug feature without a pin would still mis-resolve. Thread the resolved `ref`
  through `BehaviorSummary` to close it.
- Commands outside the run family still carry local `specs/` joins and are deliberately
  untouched: `compose`, `realize`, `realize-mock`, `wire`, `spec-fuzz`, `status`, `prove`,
  `reset`, `diff-check`, `theater`, `dream`, `replay`, `corpus`, `migrate-paths`. The
  assessment scoped these out; the resolver is now ready for them when they are converted.
- The legacy `specs/<featureName>` fallback in `declaredSignatureFor` should be deleted once
  every caller passes a resolved directory.
