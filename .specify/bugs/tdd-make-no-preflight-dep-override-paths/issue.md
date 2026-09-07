# Bug Issue: tdd make: no preflight validates dependency_overrides path targets — resolution failures surface as raw exit-255 build dumps mid-pipeline

- **Slug**: tdd-make-no-preflight-dep-override-paths
- **Fetched**: 2026-09-08
- **Issue**: 1303
- **URL**: https://github.com/arrrrny/zuraffa/issues/1303
- **State**: open
- **Severity**: medium
- **Author**: arrrrrny (Ahmet TOK)
- **Labels**: bug

## Body

### Repro

1. Flutter app scaffolded with `zfa setup` (e.g. `apps/login_demo`), then wired
   for local dev with `dependency_overrides` path entries in `pubspec.yaml`:
   ```yaml
   dependency_overrides:
     zuraffa:
       path: ../..              # exists
     zuraffa_flutter:
       path: ../../zuraffa_flutter   # DOES NOT EXIST (real checkout is a sibling: ../../../zuraffa_flutter)
   ```
2. Run the skin-lane TDD cycle: `zfa tdd gen A1` then
   `zfa tdd make A1 --author --finders-file ...`

### Expected

Either the pipeline works, or it refuses up-front with an honest,
machine-actionable verdict per the exit-code protocol (errors are an API):

```
❌ preflight: dependency_overrides["zuraffa_flutter"] path "../../zuraffa_flutter" does not resolve to a package (no pubspec.yaml)
--> fix: correct the override path or remove the entry, then re-run `zfa tdd make A1`
```

### Actual

The pipeline runs until a `build_runner`/pub step dies with a raw
version-solving dump buried mid-log:

```
⚠️  Build failed (exit 255). Retrying with clean cache...
🧹 Cleaning build cache...
   Deleted .dart_tool/build
❌ Build failed with exit code 255
Because login_demo depends on zuraffa_flutter from path which doesn't exist
(No pubspec.yaml found for package zuraffa_flutter in /…/zuraffa/zuraffa_flutter.),
version solving failed.
```

The step is then classified `generation-error`. Good parts: the subject was
restored to its certified-red shape (#1036 semantics held) and the cycle
stopped honestly — but the failure triage cost was high: the root cause (one
stale path override) is invisible in the step verdict, and the "retry with
clean cache" path burns a full rebuild on a failure that no cache clean can
fix.

### Root cause

No preflight validates that `dependency_overrides[*].path` values resolve to
directories containing a `pubspec.yaml` before the pipeline spends minutes
compiling. The provenance of the stale override is secondary (it was not
written by current `dependency_wirer.dart`, which emits version strings via
`addOverrideToPubspec`; likely an earlier tool/session run with a wrong
relative depth) — but the framework's honesty contract means the runner
should detect and name it regardless of who wrote it.

### Suggested fix

1. Preflight in `tdd make` / `tdd run` (and ideally `zfa doctor`): parse
   `dependency_overrides`, and for every `path:` value verify
   `<projectRoot>/<path>/pubspec.yaml` exists. On failure: refuse with the
   `--> fix:` line above, exit 2 (usage/grammar of the environment) or 3
   (drift — corrupt state evidence fits SPEC 917's drift class).
2. Skip the "retry with clean cache" fallback when the failure is a pub
   *resolution* error — cache state cannot fix resolution; retrying only
   wastes a rebuild.

### Context

- Found while driving the strict TDD cycle on `apps/login_demo`
  (EPIC 1/3/4/5 re-evaluation, 2026-09-07)
- The authored-red re-certification, hand-delta receipt, and subject-restore
  all behaved correctly — this issue is purely about preflight validation +
  honest classification of resolution failures
