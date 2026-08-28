# Bug Assessment: zfa build reports success but writes 0 outputs when build.yaml is missing (no zfa command creates it)

- **Slug**: issue-276-zfa-build-reports-success-but-writes-0-outputs-when-build-ya
- **Created**: 2026-08-22T19:42:20.566186+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/276
- **Verdict**: already fixed on master (verified — build guard present)
- **Severity**: config/v6/zfa_cli (per labels)

## Report (verbatim or summarized)

`zfa build` reported success ("✅ Build completed successfully") while writing
0 outputs when `build.yaml` (with the zorphy builder registered) was missing.
No `zfa` command scaffolds `build.yaml`, so a fresh workflow produced no
generated parts and a silent false success.

## Symptom

```
Built with build_runner/aot in 705s; wrote 0 outputs.
✅ Build completed successfully
```

## Reproduction

Fresh app, `zfa entity create`, then `zfa build` with no `build.yaml`.

## Suspected Code Paths

- `lib/src/commands/build_command.dart` — pre-flight + post-build output check.
- `ensureBuildYaml()` / `verifyOutputsOrFail()` / `verifyDeclaredPartsOrFail()`.

## Root Cause Hypothesis

The build reported success purely from `build_runner` exit code 0, ignoring the
0-outputs case. The fix adds a pre-flight that ensures `build.yaml` registers
the zorphy builder (failing fast when misconfigured) and a post-build safety
net that fails loudly when 0 outputs are written despite `@Zorphy` sources.

## Proposed Remediation

Already applied on master: `ensureBuildYaml()` runs before the build and
`verifyOutputsOrFail()`/`verifyDeclaredPartsOrFail()` run after; either failing
path calls `exit(1)` instead of reporting success.

## Files likely to change

- `lib/src/commands/build_command.dart` (already fixed)

## Tests to add

- `test/commands/build_command_unit_test.dart` and
  `test/commands/build_command_test.dart` cover the guard; they pass on
  `origin/master` (`c0b3758`): `+40: All tests passed!`.

## Risks & Considerations

- The full `build.yaml` *scaffolding* flow is tracked separately under #275
  (bootstrap/init); this issue's standalone robustness ask is satisfied.
- GitHub issue #276 is still OPEN although the fix is merged.

## Open Questions

- None. Not reproducible on current master.
