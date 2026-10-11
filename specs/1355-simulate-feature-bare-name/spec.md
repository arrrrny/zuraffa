**Template Version**: `zuraffa-1.0`

# Spec: 1355-simulate-feature-bare-name

GitHub issue: arrrrny/zuraffa#1355 (labels: verify-misfire, missing-integration)
Epic: #1136 (verify/epic5-simulation-replay-proof, Phase A, sub-issue 1 —
spec 968 simulation world manifests)

## Summary

`zfa simulate --scaffold specs/968-simulation-worlds && zfa simulate
--feature 968-simulation-worlds` fails with `SIMULATE -> RED
(FixtureMismatch: 968-simulation-worlds/tdd/fixtures/manifest.json —
manifest.json missing)` even though the scaffold just wrote
`specs/968-simulation-worlds/tdd/fixtures/manifest.json`. The legacy replay
flag `--feature` passes its value through verbatim, so the bare feature name
is read as a CWD-relative path — only the path form
(`specs/968-simulation-worlds`) or `--fixtures <dir>` works. The
subcommands' `--feature` already resolves bare names under `specs/`
(issue #1354 resolution), and `simulate init`'s own output recommends the
bare-name form (`zfa simulate certify test_world --feature
968-simulation-worlds`). Discovered during the EPIC verify run.

## Problem

`SimulateCommand.run()` hands the raw flag value to `_replay()`, which
boots `SimulationWorld` from the value as-is. Bare name → relative path →
FixtureMismatch. The fix must apply ONLY to the legacy replay entry (the
scenario subcommands were fixed by #1354) and must stay backward
compatible with every invocation that works today.

## Locked decisions

1. Fix ONLY the legacy `--feature` replay resolution. `--fixtures` (the
   explicit-dir flag) is honored verbatim — never specs/-resolved; the
   scenario subcommands' resolution (#1354) is untouched; the scaffold,
   replay verdict, and guard semantics are untouched.
2. Resolution rule for `--feature`: a bare name (contains no `/`) resolves
   to `<cwd>/specs/<name>` WHEN that directory exists; otherwise the raw
   value is kept so the boot failure names exactly what the user passed.
   Path-form values (contain `/`) are always honored verbatim — today's
   working invocations cannot change behavior.
3. No new flag, no parser change, no help-text lie: the `--feature` help
   documents the bare-name default after this fix (it currently reads
   "Load the committed world from <feature-dir>/tdd/fixtures/" — extend it
   with the bare-name rule).
4. Exit codes and the `SIMULATE -> GREEN/RED` verdict protocol are
   unchanged.

## Functional requirements

- **FR-1 (bare-name resolution)**: `zfa simulate --scaffold specs/<f>`
  followed by `zfa simulate --feature <f>` (bare name) MUST replay GREEN
  from `<cwd>/specs/<f>/tdd/fixtures/` — no path form required.
- **FR-2 (verbatim paths)**: `--feature specs/<f>` (path form) and
  `--fixtures <dir>` behave exactly as before the fix.
- **FR-3 (honest miss)**: a bare name whose `specs/<name>` directory does
  not exist keeps the raw value — the boot's FixtureMismatch names the
  value as passed (never a crash, never a guess).
- **FR-4 (docs)**: the parent `--feature` help documents the bare-name
  rule.

## Acceptance scenarios (measurable)

1. **Given** a workspace whose `specs/<f>/tdd/fixtures/` holds a
   scaffolded manifest (via `--scaffold`), **when** `zfa simulate
   --feature <f>` runs from the workspace root, **then** the replay is
   GREEN (exit 0) loading the fixtures under `specs/<f>` — the issue's
   exact repro.
2. **Given** the same workspace, **when** `zfa simulate --feature
   specs/<f>` runs, **then** the replay is GREEN exactly as before
   (regression guard for the path form).
3. **Given** a bare name with no `specs/<name>` directory, **when**
   `zfa simulate --feature <name>` runs, **then** it exits 1 RED and the
   message names `<name>/tdd/fixtures/manifest.json` (the raw value as
   passed, the pre-fix behavior).
4. **Given** a fixtures directory outside `specs/`, **when** `zfa
   simulate --fixtures <dir>` runs, **then** the replay uses that
   directory verbatim (no specs/ resolution for `--fixtures`).

## Success criteria

### Measurable Outcomes

- **SC-001**: The issue's repro sequence (`--scaffold` then bare-name
  `--feature`) replays GREEN without the workaround.
- **SC-002**: All pre-existing `--feature`/`--fixtures` invocations in the
  simulate suites pass unchanged.

## Assumptions

- The bare-name rule mirrors the subcommands' #1354 resolution (bare name
  under `specs/`), keeping one feature-name convention across the command.
- Resolution is against the process CWD — the legacy replay has no
  `--project` flag, matching the pre-fix relative-path semantics.
