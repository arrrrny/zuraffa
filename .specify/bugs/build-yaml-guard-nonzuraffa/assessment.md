# Bug Assessment: `zfa build` fails closed on a `build.yaml` without the zorphy builder even when the project has no zorphy usage, dead-ending `zfa tdd refactor`

- **Slug**: build-yaml-guard-nonzuraffa
- **Created**: 2026-10-17T18:52:01Z
- **Source**: https://github.com/arrrrny/zuraffa/issues/1709
- **Verdict**: valid (root cause confirmed in code; reported symptom reproduced end-to-end)
- **Severity**: high for non-zuraffa packages that own a `build.yaml` (their
  `zfa tdd refactor` can never reach the done transition)

## Report (summarized)

A Flutter **package** (`arrrrny/zuraffa_ui`) — the repackaged shadcn vocabulary
+ `ZuraffaApp` — is not a zuraffa app: zero `@Zorphy` annotations, no zorphy
dependency, and its own `build.yaml` for unrelated builders
(`theme_extensions_builder`, `slang_build_runner`). Running
`zfa tdd run .specify/bugs/shadapp-missing-scaffoldmessenger` dead-ends at
phase 2 (the first refactor) because the fixed pass registry spawns
`zfa build`, which refuses:

```
$ zfa build
   Entities: 0, Dart files: 272
❌ build.yaml exists but does not register the zorphy builder.
   ...
```

`--no-analyze --no-dda-routes` fails identically — there is no flag that
bypasses the check. The suggested remedies are destructive on this project:
deleting `build.yaml` removes the `slang_build_runner` configuration the
package depends on, and `zfa setup` regenerates the file for the zuraffa
pipeline.

## Symptom

Observed: `zfa build` hard-fails whenever `build.yaml` exists without a
`zorphy:zorphy` entry, regardless of whether the project has any `@Zorphy`
annotations or a zorphy dependency. Expected: with zero `@Zorphy` entities and
no zorphy dependency in the graph, the build pass should no-op successfully.

## Reproduction

1. Create a non-zuraffa Dart/Flutter package: a `pubspec.yaml` with no zorphy
   dependency, a `build.yaml` for its own builders, and plain Dart sources
   under `lib/`.
2. Run `zfa build` (or `zfa build --no-analyze --no-dda-routes`).
3. Observe exit 1 with `build.yaml exists but does not register the zorphy
   builder.` on the pre-fix tree — reproduced on `115240bc` with the installed
   CLI (`Entities: 0, Dart files: 1`, exit 1).
4. In a TDD run, this is the refactor's `build` pass, so the first behavior's
   refactor reports `runner-error` and every resume repeats it.

## Suspected Code Paths

- `lib/src/commands/build_yaml_guard.dart:39` — `BuildYamlGuard.check` decides
  `missingZorphyBuilder` purely from the presence of the `zorphy:zorphy` regex
  match in `build.yaml`; it never consults zorphy usage.
- `lib/src/commands/build_command.dart:554` — `ensureBuildYaml` turns
  `missingZorphyBuilder` into `return false`, and `run()` exits 1
  (`build_command.dart:170-174`) before build_runner is invoked.
- `lib/src/commands/build_command.dart:575` — `reportBuildYamlDryRun` mirrors
  the same verdict for `--dry-run`.
- `lib/src/plugins/tdd/services/refactor_passes.dart:340` — the fixed pass
  registry always resolves a `build` pass (`zfa build`), gated only by
  `BuildRelevance.refactorBuildSkipNote`. The reported project has a
  user-authored (non-pristine) `build.yaml`, so the static first-build scan
  returns `null` (run) and the dead-end is guaranteed.

## Root Cause Hypothesis

Confidence: **high**. `BuildYamlGuard.check` is a pure build.yaml-content
check. Its original contract (zuraffa#276) is to fail loudly when a
zuraffa-pipeline project's `build.yaml` would let build_runner exit 0 with 0
outputs — but it does not distinguish "this project's `build.yaml` omits the
zorphy builder although it uses zorphy" from "this project never uses zorphy
and the omitted registration is irrelevant". On a project with no `@Zorphy`
sources and no zorphy dependency the guard is simply not applicable, yet it
fails closed; the TDD refactor's fixed pass registry has no path around it.

## Proposed Remediation

**Preferred**: teach the guard to stand aside when the project provably does
not use the zuraffa/zorphy code-generation pipeline. Add
`BuildYamlStatus.notApplicable`, returned by `BuildYamlGuard.check` when
`build.yaml` omits `zorphy:zorphy` **and** the project has neither a
`@Zorphy`/`@ZorphyMixin`-annotated source under `lib/` nor a `zorphy` /
`zorphy_annotation` dependency in `pubspec.yaml`. Require a `pubspec.yaml` for
that proof, so a bare `build.yaml` (the zuraffa#276 regression fixture) keeps
its fail-closed behavior. `ensureBuildYaml` returns `true` with an
informational note for `notApplicable`, and `reportBuildYamlDryRun` mirrors it,
so the build proceeds with the project's own builders and the TDD refactor's
`build` pass succeeds. The annotation scan moves from `BuildCommand` into
`BuildYamlGuard` (shared, one implementation) and `BuildCommand` delegates.

**Alternatives**:
- Skip the TDD refactor's `build` pass outright when the project has no zorphy
  usage (extend `BuildRelevance.refactorBuildSkipNote`). Unnecessary once
  `zfa build` itself no longer fails; it would also hide a legitimately
  configured project's own build.
- Add a `--skip-build-yaml-guard` flag. Rejected: the issue asks for the
  auto-detection, and a flag pushes the burden onto every consumer.

**Files likely to change**:
- `lib/src/commands/build_yaml_guard.dart`
- `lib/src/commands/build_command.dart`
- `test/commands/build_yaml_guard_test.dart`
- `test/commands/build_command_unit_test.dart`

**Tests to add or update**:
- `check()` returns `notApplicable` for a real project (pubspec, own
  `build.yaml`, no zorphy usage).
- `check()` still returns `missingZorphyBuilder` when the pubspec declares
  zorphy, when a `@Zorphy` source exists, and when there is no `pubspec.yaml`.
- `ensureBuildYaml` returns `true` with the not-applicable note and leaves the
  user's `build.yaml` untouched.
- `reportBuildYamlDryRun` reports the not-applicable pass instead of the
  "0 outputs" warning.

## Risks & Considerations

- False "notApplicable" on a real zuraffa app would silently skip the
  registration warning. Mitigated by consulting BOTH signals (annotation scan
  and pubspec dependency) and by requiring a `pubspec.yaml`; any doubt keeps
  the pre-#1709 fail-closed verdict.
- The same-project builders (`slang`, `theme_extensions`) still run, and the
  post-build verifiers (`verifyOutputsOrFail`, `verifyDeclaredPartsOrFail`) and
  the analyze gate are unchanged — so a genuinely broken non-zorphy build still
  fails loudly.

## Open Questions

- None blocking. Where the TDD refactor chooses to *skip* rather than *run* a
  not-applicable build pass is left as a follow-up: with this fix the pass
  succeeds, which is what the issue's Expected clause requires.
