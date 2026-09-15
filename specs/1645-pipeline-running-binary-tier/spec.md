# Feature Specification: Pipeline entrypoint resolution — the running compiled binary outranks the PATH tier

**Template Version**: `zuraffa-1.0`

**Feature Branch**: `fix/1645-pipeline-running-binary-tier`

**Created**: 2026-09-15

**Status**: Draft

**Input**: User description: "Issue #1645 — PipelineRunner._resolveEntrypoint: PATH tier outranks the running compiled binary (same-version/different-code hazard). Follow-up from #1643 (the StepRunner.resolveEntrypoint fix for #1636): apply the same conditional promotion to the pipeline chain, keep the VM driver order unchanged (backward compatible), mirroring #1643's tier reorder and its test shapes (B1–B5)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The driving binary always drives the pipeline (Priority: P1)

An operator runs the zfa CLI as a compiled (non-Dart-VM) binary — for
example the `scripts/zfa` compile-cache artifact — and drives a TDD
pipeline (`tdd make` / `gen` spawns, the #665 chain). Every child the
pipeline spawns executes the SAME binary the operator invoked, even when
an older `zfa` install sits on PATH carrying the same version string.
Today the PATH tier short-circuits such runs, so the pipeline can silently
execute same-version/different-code code — a hazard the #1472 version pin
cannot detect (it only fires on a provably different version).

**Why this priority**: This is the bug itself. The no-JIT directive is
"the driving built binary always"; the pipeline chain is the one remaining
resolver that can silently violate it for compiled drivers.

**Independent Test**: With the platform facts injected (a compiled driving
executable, a `zfa` on PATH), the pipeline resolves its entrypoint to the
driving executable — fully testable at the resolver tier without compiling
a real binary.

**Acceptance Scenarios**:

1. **Given** the CLI runs as a compiled binary whose script basename is
   not `zfa.dart`/`zuraffa.dart` (the #864 native-AOT shape, where the
   script IS the executable) and a `zfa` exists on PATH, **When** the
   pipeline resolves its entrypoint, **Then** the resolved entrypoint is
   the running binary itself — never the PATH install.
   **Type**: acceptance
2. **Given** the same compiled driver with an unusable script path (the
   stale-snapshot shape) and a `zfa` on PATH, **When** the pipeline
   resolves its entrypoint, **Then** the running binary wins.
   **Type**: acceptance
3. **Given** a compiled driver and a PATH directory whose `zfa` candidate
   is not executable, **When** the pipeline resolves its entrypoint,
   **Then** the running binary wins and the non-executable PATH candidate
   never does.
   **Type**: unit

---

### User Story 2 - VM drivers keep today's order exactly (Priority: P2)

An operator driving the CLI through a Dart VM launch (`dart run`, a
`dartaotruntime` snapshot) keeps the resolution order #665/#690
established: a system `zfa` on PATH still outranks the script/snapshot
fallbacks. The promotion is conditional on the driving executable being a
compiled (non-VM) binary, so VM-driver behavior is byte-identical to
before — backward compatible by construction.

**Why this priority**: Backward compatibility is the fix's hard
constraint; without it the reorder would break source and snapshot
workflows.

**Independent Test**: With a VM-named driving executable injected, a
`zfa` on PATH still wins over the snapshot fallback, and the compiled
snapshot keeps the `<vm> <snapshot>` spawn shape.

**Acceptance Scenarios**:

1. **Given** a VM driver (`dart` / `dartvm` / `dartaotruntime`, Windows
   `.exe` variants included) and a `zfa` on PATH, **When** the pipeline
   resolves its entrypoint, **Then** the PATH install wins exactly as
   before the change.
   **Type**: unit
2. **Given** a VM driver, no `zfa` on PATH, and a compiled-snapshot
   script path, **When** the pipeline resolves its entrypoint, **Then**
   the `<vm> <snapshot>` shape is preserved (the snapshot is never
   collapsed to a bare executable).
   **Type**: unit
3. **Given** a VM driver running from source (`bin/zfa.dart` /
   `bin/zuraffa.dart`), **When** the pipeline resolves its entrypoint,
   **Then** the source is compiled and the artifact runs alone (the
   no-JIT tier-2 contract, unchanged).
   **Type**: unit

---

### User Story 3 - The override and the pin are untouched (Priority: P3)

An explicit `--zfa-bin` override keeps absolute precedence (tier 1), and
the #1472 version pin keeps its semantics: with the fix, a compiled
driver's resolution IS the driving binary, so the pin's version probe
returns equal and no swap fires; the pin still swaps on a provably
different-version candidate exactly as before.

**Why this priority**: Guards against scope creep into the neighboring
contracts the issue explicitly leaves alone.

**Independent Test**: The existing override and #1472 gate suites pass
unchanged.

**Acceptance Scenarios**:

1. **Given** an explicit `--zfa-bin` path, **When** the pipeline resolves
   its entrypoint, **Then** the override wins before any tier is
   consulted.
   **Type**: unit
2. **Given** the #1472 gate suites, **When** the regression scope runs,
   **Then** they pass unchanged (the pin's code is not modified).
   **Type**: unit

---

### Edge Cases

- What happens when the driving executable's basename is non-VM but the
  file does not exist on disk? The promoted tier must not fire (the
  existence check fails) and resolution falls through to PATH exactly as
  before.
- What happens on Windows? The VM-name check covers `dart.exe`-style
  names; the promotion condition and tier order behave identically.
- What happens when PATH holds no `zfa` at all for a compiled driver?
  The running binary is resolved by the new tier before the miss is ever
  reached; the final fallbacks stay reachable for VM drivers only.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST resolve the pipeline entrypoint to the RUNNING
  executable ahead of the PATH tier whenever the driving executable is a
  compiled (non-Dart-VM) binary that exists on disk.
- **FR-002**: System MUST keep the existing tier order for VM drivers
  (`dart`, `dartvm`, `dartaotruntime` and their `.exe` variants): the
  PATH tier still outranks the script/snapshot fallbacks (backward
  compatible).
- **FR-003**: System MUST keep the explicit `--zfa-bin` override as the
  first tier, ahead of every automatic resolution.
- **FR-004**: System MUST keep the running-from-source tier (`zfa.dart`/
  `zuraffa.dart` script basenames) and its compile-before-spawn behavior
  unchanged.
- **FR-005**: System MUST keep the no-JIT guarantee: every resolution
  that lands on a Dart source is compiled before it is returned, and a
  compiled candidate is never respawned through the VM.
- **FR-006**: System MUST keep the compiled-snapshot fallback shape
  (`<vm> <snapshot>`) for VM drivers when nothing else resolves.
- **FR-007**: System MUST NOT modify the #1472 version-pin behavior or
  the build-pass delegation while restoring the driving-binary guarantee.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With a compiled driving binary and a stale same-version
  `zfa` on PATH, the pipeline resolves and spawns the driving binary
  (proven at the resolver tier with injected platform facts — the repo's
  fast-tier convention; no real AOT compile in tests).
- **SC-002**: VM-driver resolution is behaviorally identical to the
  pre-change order: every existing tier contract test passes after
  re-shaping any synthetic VM stand-ins to real VM names, with their
  protective intent preserved.
- **SC-003**: The scoped TDD services regression suite and the #1472
  gate suites stay green, and the changed files add zero analyzer
  findings.

## Assumptions

- The promotion condition mirrors #1643 byte-for-byte in intent: the
  resolved-executable basename fails the Dart VM name check (`dart`,
  `dartvm`, `dartaotruntime`, `.exe` variants) AND the executable exists.
- Scope is the pipeline resolver only (the #665 chain used by `tdd
  make`/`gen` spawns); the step runner was already fixed by #1643 and is
  out of scope.
- Verification happens at the resolver tier with injected platform facts
  (`script`/`resolvedExecutable`/`PATH` seams), matching how the #864
  tier contract is pinned today; a real end-to-end AOT compile is out of
  scope for tests.
- Existing tests that stand in for the Dart VM with a compiled-fake
  basename (`dart-vm`) are re-shaped to real VM names rather than
  loosened — the same precedent #1643 set for the step runner's tier
  tests.
