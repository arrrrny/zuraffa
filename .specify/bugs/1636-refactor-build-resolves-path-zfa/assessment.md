# Bug Assessment: refactor build pass resolves the PATH-installed zfa instead of the driving binary

- **Slug**: 1636-refactor-build-resolves-path-zfa
- **Created**: 2026-09-15T14:20:00+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/1636
- **Verdict**: valid (root cause confirmed in code; reproducible by construction at the tier level)
- **Severity**: high (silently runs different code than the driving CLI for the heaviest child a refactor spawns)

## Report

When the driving CLI is a compiled (non-VM) binary that is not on PATH (e.g. the
`.dart_tool/zfa_cli_bin/zfa_exe` compile-cache artifact, master @ 8480a53e),
`scripts/zfa tdd refactor` records its build pass as
`/Users/<user>/.local/bin/zfa build` — the PATH install — instead of the
driving binary. The PATH install may predate the driving build while carrying
the same `6.3.0` version string, which the #1472 version pin cannot
distinguish (it only fires on a provably different version).

## Symptom

The refactor's build pass (the heaviest child a refactor spawns) executes
different code than the CLI driving the run, violating the no-JIT directive
"the driving built binary always".

## Reproduction

1. Compile the CLI from master into the compile cache
   (`.dart_tool/zfa_cli_bin/zfa_exe` — what `scripts/zfa` does per run).
2. Have an older `zfa` on PATH (e.g. `~/.local/bin/zfa`, same version string).
3. Run `scripts/zfa tdd refactor A1 --feature calculator --project <proj>`.
4. Observe the build pass line: `command: <PATH-install> build` — not the
   driving `.dart_tool/zfa_cli_bin/zfa_exe`.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/step_runner.dart` —
  `StepRunner.resolveEntrypoint`: the tier chain is
  tiers 1-3 (source: script-basename → sibling `bin/zfa.dart` → package
  config) → tier 4 (PATH `zfa`, concrete no-shell lookup, bug #690) →
  tier 5 (`Platform.script` as a usable file) → tier 6
  (`Platform.resolvedExecutable` when it is not the Dart VM).
- `lib/src/plugins/tdd/services/refactor_passes.dart` — `zfaBuildCommand`
  delegates the entrypoint search to `StepRunner.resolveEntrypoint`
  (with the package tier suppressed per bug #717) and shapes the build
  pass command line from the result. This is why the fix in
  `StepRunner.resolveEntrypoint` repairs the build pass without touching it.
- Tier history that constrains the fix: #690 (PATH tier + resolvedExecutable
  final fallback), #864 (`Platform.script` IS `Platform.resolvedExecutable`
  for a native AOT exe), #1371 (tier-1 existence check), #1472 (version pin).

## Root Cause Hypothesis (confirmed by code reading)

`StepRunner.resolveEntrypoint` orders the PATH tier (4) BEFORE the
running-binary tier (6). For a compiled driver whose `resolvedExecutable` is
a non-VM executable, tiers 1-3 are unreachable in production
(#864: in a native AOT exe `Platform.script` IS `Platform.resolvedExecutable`,
whose basename is neither `zfa.dart`/`zuraffa.dart` nor a sibling `bin/zfa.dart`;
the package tier does not resolve from a compiled system binary), so tier 4
short-circuits and every resolved child — including the build pass — executes
the PATH install. The #1472 pin probes `--version` and cannot distinguish a
same-version/different-code PATH install from the driving binary.

## Proposed Remediation

Reorder only — in `StepRunner.resolveEntrypoint`, when
`Platform.resolvedExecutable` is a compiled (non-VM) executable that exists,
return it BEFORE the PATH tier (the running binary is definitionally what the
operator invoked). Concretely: hoist the existing final
`resolvedExecutable`-fallback condition to sit between the package tier and
the PATH tier. VM drivers (`dart run`, `dart test`, `dartaotruntime`
snapshots) fail the non-VM check and keep the exact #690/#717 order —
backward compatible. The build pass (`zfaBuildCommand`) and the #1472 pin
(`_pinToDrivingVersion`) are NOT changed; they inherit the corrected order
through the delegation they already perform. With the fix, a compiled
driver's candidate IS the driving binary, so the pin's version probe returns
equal and no swap fires — the pin still fires for genuinely different-version
candidates exactly as before.

## Risks & Considerations

- Each tier exists for a repro (#690/#864/#1371/#1472): the hoisted condition
  is byte-identical to the old final tier's condition, so every driver shape
  that resolved via the final tier now resolves earlier with the same result.
- The existing "usable `Platform.script` wins over the resolvedExecutable
  fallback" test used a synthetic mixed shape (JIT-snapshot script + compiled
  `resolvedExecutable`) that no production driver produces (#864 proves a
  real AOT exe has `script == resolvedExecutable`; a real JIT snapshot runs
  under the VM). Under the corrected order the running binary legitimately
  outranks the script tier for that synthetic shape; the test is re-shaped to
  the realistic JIT-snapshot driver (VM `resolvedExecutable`) preserving its
  protective intent.
- `defaultZfaBin` passes the resolution through `ZfaExecutable.ensureCompiled`,
  which returns non-`.dart` candidates unchanged — the compiled driver's own
  binary flows through without a recompile.

## Open Questions

- None blocking. Fix direction matches the issue's; scope is the tier order
  in `StepRunner.resolveEntrypoint` only.
