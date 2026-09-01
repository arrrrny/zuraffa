# Bug Assessment: zfa tdd requires explicit --zfa-bin on new projects (not seamless)

- **Slug**: tdd-zfa-bin-required-on-new-projects
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/665
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim or summarized)

Running `zfa tdd run/make/verify` against a fresh checkout or global install fails because the zfa binary entrypoint cannot be resolved automatically. Users are forced to pass `--zfa-bin <path>` explicitly every time. The error:

```
PipelineResolutionError: cannot resolve the zfa entrypoint. The command needs to invoke
`zfa entity create` / `zfa make` / `zfa build` as sub-processes, but neither --zfa-bin,
Platform.script (running from source), nor `zfa` on PATH resolved.
```

Two separate but related resolution strategies exist:

1. **PipelineRunner** (used by `make`, `gen`, `verify`): three-tier fallback
   (`--zfa-bin` → `Platform.script` ending in `zfa.dart`/`zuraffa.dart` → PATH `zfa`).
   When running from a compiled snapshot or global activate, `Platform.script` points
   elsewhere, and if `zfa` is not on PATH, everything fails with no further fallback.
2. **StepRunner** (used by `run` command): uses
   `Isolate.resolvePackageUri('package:zuraffa/src/zfa_cli.dart')`, which requires the
   package to be on the package path — not true when the CLI is installed globally or run
   as a compiled binary.

## Symptom

`zfa tdd` commands fail on fresh checkouts / global installs unless `--zfa-bin <path>`
is passed explicitly every time, defeating the "seamless" UX goal.

## Reproduction

1. On a machine or environment where `zfa` is not on PATH (e.g. after
   `dart pub global activate` without PATH wrapping, or a fresh clone).
2. Run `zfa tdd run <feature>` without `--zfa-bin`.
3. Observe the `PipelineResolutionError`.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/pipeline_runner.dart` — three-tier fallback
  (`--zfa-bin` → `Platform.script` → PATH `zfa`); no final fallback for
  compiled-snapshot / global-activate scenarios.
- `lib/src/plugins/tdd/services/step_runner.dart` — uses
  `Isolate.resolvePackageUri('package:zuraffa/src/zfa_cli.dart')`, which fails
  when the CLI is installed globally or run as a compiled binary.

## Root Cause Hypothesis

The resolution chain has two gaps: (1) PipelineRunner's `Platform.script` check
requires the basename to be `zfa.dart`/`zuraffa.dart`, which is false for compiled
snapshots and global activates; (2) StepRunner relies on package-URI resolution,
which is unavailable in those same scenarios. Confidence: **high** — the issue
reproduces deterministically and the proposed fix is mechanical.

## Proposed Remediation

**Preferred**: Extend the resolution chain to use
`Platform.resolvedExecutable` + `Platform.script.toFilePath()` as a final fallback,
regardless of whether the script basename is `zfa.dart`. This mirrors the source-run
case but catches the compiled-snapshot and global-activate scenarios too.

Files likely to change:
- `lib/src/plugins/tdd/services/pipeline_runner.dart` — add the
  `Platform.resolvedExecutable` + `Platform.script` fallback
- `lib/src/plugins/tdd/services/step_runner.dart` — replace
  `Isolate.resolvePackageUri` with the same `Platform.script` +
  `Platform.resolvedExecutable` strategy

**Alternatives**: none material; this is the minimal, mechanical fix.

**Tests to add or update**:
- `zfa tdd run` succeeds on a fresh checkout without `--zfa-bin` (no PATH `zfa`).
- `zfa tdd make` / `zfa tdd verify` succeed without `--zfa-bin`.
- Regression: explicit `--zfa-bin` still overrides resolution.

## Risks & Considerations

- `Platform.resolvedExecutable` may point to the Dart VM snapshot in some
  environments; verify the resolved entrypoint actually runs `zfa` sub-commands.
- Changing resolution must not break the source-run path (`Platform.script` basename
  `zfa.dart`).

## Open Questions

- None blocking.