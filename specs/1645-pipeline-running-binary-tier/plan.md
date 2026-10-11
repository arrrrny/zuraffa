**Template Version**: `zuraffa-1.0`

# Plan: 1645-pipeline-running-binary-tier

**Branch**: `fix/1645-pipeline-running-binary-tier` | **Date**: 2026-09-15 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `specs/1645-pipeline-running-binary-tier/spec.md` (issue #1645, follow-up to #1643)

## Summary

`PipelineRunner._resolveEntrypoint` (the #665 chain behind `tdd make`/`gen`
spawns) orders its tiers `Platform.script` (2) → PATH `zfa` (3) → fallbacks
(4). For a compiled (non-VM) driving binary whose script basename is not
`zfa.dart`/`zuraffa.dart` — the `scripts/zfa` compile-cache artifact
`.dart_tool/zfa_cli_bin/zfa_exe` (#864 native-AOT shape) — tier 2 falls
through and the PATH tier short-circuits: a same-version/different-code
PATH install drives the pipeline, invisible to the #1472 version pin. The
fix promotes the #1643 conditional to this chain: when
`Platform.resolvedExecutable` is a compiled (non-VM) executable that
exists, it is resolved AHEAD of the PATH tier. VM drivers keep the exact
#665/#690 order — backward compatible.

## Technical Context

- Language/Dart SDK: `^3.11.0` (repo pin), running on Dart 3.13.3 stable
  (macOS arm64 this session). Pure-Dart root package.
- Surface modified (one file, ordering + docs only):
  - `lib/src/plugins/tdd/services/pipeline_runner.dart` —
    `_resolveEntrypoint` (L~413): one new tier between tier 2 (source
    script) and tier 3 (PATH); library docs + method docs renumbered with
    the #1645 rationale. No signature changes: the existing test seams
    (`scriptPathOverride`, `resolvedExecutableOverride`,
    `pathEnvOverride`, `ensureCompiled`) already cover the new tier.
- Surfaces NOT modified (hard constraints, FR-007):
  - `StepRunner.resolveEntrypoint` — already fixed by #1643 (running
    binary tier 4, PATH tier 5); untouched.
  - `refactor_passes.dart` (`zfaBuildCommand`, `_pinToDrivingVersion`) —
    the #1472 pin and the build-pass delegation inherit the fix through
    `StepRunner`, not this chain; untouched.
  - `_findExecutableOnPath`, `_platformScriptPath`, `ZfaExecutable` —
    reused as-is.
- Test seams (existing, reused): `PipelineRunner.runPlan` overrides
  (`scriptPathOverride`/`resolvedExecutableOverride`/`pathEnvOverride`/
  `ensureCompiled`) + `TddFixture.writeFakeZfaBin` — the argv-logged fake
  zfa makes the resolved entrypoint observable via `result.entrypoint`
  and the spawn shape observable via the argv log (the same harness the
  bug-#864 tier group in `pipeline_runner_test.dart` uses).

## Design

### 1. The promoted tier (ordering only)

In `_resolveEntrypoint`, between tier 2 (running from source) and tier 3
(PATH):

```dart
// Tier 3 (bug #1645): the RUNNING binary. When this process runs as a
// compiled (non-VM) executable — the scripts/zfa compile-cache artifact,
// an install dir elsewhere on PATH — it is definitionally what the
// operator invoked ... (the #1643 rationale, mirrored)
if (!_isDartVmName(p.basename(resolvedExecutable)) &&
    await File(resolvedExecutable).exists()) {
  final compiled = await compile(resolvedExecutable);
  return _ResolvedEntrypoint(
    executable: compiled,
    displayCommand: compiled,
  );
}
```

- The condition is byte-identical in intent to #1643's promoted tier:
  `!_isDartVmName(basename(resolvedExecutable)) && exists`. A non-`.dart`
  candidate flows through `compile` (the `ZfaExecutable.ensureCompiled`
  seam) unchanged — the same pass-through every other tier uses — so the
  no-JIT invariant (FR-005) holds by construction.
- VM drivers fail the name check and fall through to PATH (tier 4) and
  the `dart <snapshot>` fallback (tier 5) exactly as #665/#690 ordered —
  FR-002/FR-006 preserved.
- Tier 1 (`--zfa-bin`) and tier 2 (source, compile-before-spawn) keep
  their places — FR-003/FR-004.

### 2. VM-name predicate

`PipelineRunner` gains a private static `_isDartVmName` mirroring
`StepRunner._isDartVmName` (`dart`, `dartvm`, `dartaotruntime` + `.exe`),
with a doc comment cross-referencing the step-runner twin. See research.md
for the reuse-vs-mirror decision.

### 3. Existing tier tests re-shaped, not loosened

The bug-#864 tier group stands in for the Dart VM with a compiled fake
named `dart-vm` (U16 "PATH wins over snapshot fallback", U17 "snapshot
keeps `<vm> <snapshot>` shape"). `dart-vm` FAILS the VM-name check, so
under the promoted tier those synthetic shapes would resolve the running
binary — the tests would flip red for a shape no production VM launch
produces. Per the #1643 precedent, U16/U17 are re-shaped to a REAL VM
name (`dart`): the fake is renamed, intent and assertions unchanged.
U14 (native AOT, PATH nonexistent) and U15 (source tier) are unaffected.

## Alternatives rejected

- Reuse `StepRunner._isDartVmName` by making it public: changes the
  step-runner API surface and adds a services-internal import for one
  5-line predicate. The private mirror (with a cross-reference comment)
  keeps both resolvers self-contained, exactly as #690 mirrored #665's
  PATH tier without coupling. If a third consumer appears, extract then
  (the #1610 precedent: extract on duplication, not speculation).
- Promoting the running binary unconditionally (dropping the VM-name
  check): would make `dart run`/`dart test` resolve the bare VM as the
  zfa entrypoint — the exact bug class #690's name check exists to
  prevent.
- Fixing the hazard in the #1472 pin (probe content hash instead of
  version): expands the pin's contract and spawns extra probes per
  resolution; the ordering fix removes the hazard at the source. The
  pin stays scoped to provably-different versions.
- Waiting for #1643 to merge and "rebase on it": the pipeline fix is
  textually and semantically independent (different file, different
  chain); basing this branch on master avoids stacking PRs.

## Verification

- Red tests first: the new `bug_1645` tier suite (B1/B2 mirror shapes)
  runs red pre-fix, green post-fix; B3–B5 (backward-compat guards) green
  throughout (see `tdd/test-list.md`).
- Regression scope: `test/plugins/tdd/services/` (includes the re-shaped
  bug-#864 tier group), the #1472 gate suites, the no-JIT sweep
  (`test/core/no_jit_zfa_spawn_scan_test.dart`).
- `dart analyze` on changed files: zero findings; `dart format` clean.
- data-model.md: not generated — no data entities (spec declares none).
- contracts/: not generated — no interface contract changes (internal
  resolver ordering; public CLI surface unchanged).

## Constitution Check

`.specify/memory/constitution.md` is an unfilled template (no ratified
project principles) — no gates to evaluate. The repo's de-facto
constraints honored: red-before-green evidence, no-JIT spawn sweep,
fast-tier test convention (no real AOT compile in tests), reorder-only
scope with neighboring contracts pinned by their existing suites.
