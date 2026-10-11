**Template Version**: `zuraffa-1.0`

# Spec: 1354-simulate-positional-scenario

GitHub issue: arrrrny/zuraffa#1354 (labels: verify-misfire, spec-drift)
Epic: #1136 (verify/epic5-simulation-replay-proof, Phase A, sub-issue 1 —
spec 968 simulation world manifests)

## Summary

`zfa simulate init test_world` refuses with `❌ no --feature given --> fix:
pass --feature <name-or-dir>` even though the documented grammar is
`zfa simulate <init|run|certify|verify-world> <scenario> [options]` and the
epic #1136 Phase A table expects `zfa simulate init test_world` to scaffold a
world manifest. The positional scenario IS parsed, but the feature is
mandatory-only: `_resolveFeature` (`lib/src/commands/simulate_command.dart`)
throws a usage error whenever `--feature` is absent, so the bare documented
invocation never scaffolds anything. Discovered during the EPIC verify run;
tracked as issue #1354.

## Problem

The scenario-worlds subcommands (`init`, `run`, `certify`, `verify-world`)
share `_resolveFeature`, which resolves the feature exclusively from the
explicit `--feature` flag (subcommand-level or the parent's flag). Every
other feature-scoped surface in this CLI already treats the speckit session
pin as the default: `bone_command.dart` resolves "positional arg >
`.specify/feature.json` > error", and the mock capabilities fall back to the
pinned `.specify/feature.json` (`certify_mock_capability.dart`,
`_pinnedFeature`) when `--feature` is omitted. The simulate subcommands were
never wired to that fallback, so the documented positional invocation fails
in any session where the feature was pinned the standard way (`zfa tdd plan
<feature>` writes `feature_directory`).

Workaround today (from the issue): `zfa simulate init test_world --feature
968-simulation-worlds` → GREEN, world manifest written to
`specs/968-simulation-worlds/tdd/worlds/test_world.world.json`.

## Locked decisions

1. Fix ONLY the feature resolution of the simulate scenario subcommands
   (`_resolveFeature` and the usage/help text that documents it). The world
   scaffold, certification, run, receipt, differential gate, cycle-log
   evidence, legacy flag surface (`--scaffold`, `--fixtures`, `--scenario`,
   `--verify-guard`, ...), and parser-only subcommand registration (bug
   #856) are UNCHANGED.
2. Resolution order: explicit `--feature` (subcommand level, falling back to
   the parent-level flag) FIRST, then the pinned
   `.specify/feature.json` `feature_directory`, then an honest usage error.
   An explicit flag always beats the pin — pinning never overrides an
   explicit argument.
3. The pin accepts both forms the rest of the CLI accepts: a bare feature
   name (`968-simulation-worlds`) and a `specs/`-prefixed path
   (`specs/968-simulation-worlds`). A pin pointing at a directory that does
   not exist is an honest usage error naming the missing path — never a
   silent fallback, never a guess scanning `specs/`.
4. The same resolution applies to all four scenario subcommands (they share
   the resolver by design). `init`, `run`, `certify`, and `verify-world`
   gain the pin fallback together.
5. Usage and `--help` text for the subcommands documents `--feature` as
   optional-with-pin, and the no-feature error names the exact steps tried
   (explicit flag absent, pin absent/missing) plus the fix. No error message
   may claim the positional scenario was ignored — the scenario parses; what
   failed is feature resolution.
6. Exit-code semantics are unchanged: an unresolvable feature is a usage
   error (`ExitProtocol.usage`), a successful scaffold is exit 0. The
   committed cycle-log evidence keeps recording the RESOLVED feature name in
   its `commandLine`, so a bare invocation and its explicit-`--feature`
   equivalent produce replayable evidence lines.

## Functional requirements

- **FR-1 (pin fallback)**: `zfa simulate <subcommand> <scenario>` WITHOUT
  `--feature` MUST resolve the feature from the pinned
  `.specify/feature.json` `feature_directory` of the project root (or
  `--project` root when given) and behave exactly as if that feature had
  been passed explicitly.
- **FR-2 (explicit wins)**: An explicit `--feature` (subcommand level or
  parent level) MUST always win over the pin. When both exist and differ,
  the manifest is written under (or loaded from) the EXPLICIT feature.
- **FR-3 (shared resolver)**: The pin fallback MUST apply to `init`, `run`,
  `certify`, and `verify-world` alike through the shared `_resolveFeature`.
- **FR-4 (honest refusal)**: When no explicit flag is given AND no
  `.specify/feature.json` exists (or it carries no `feature_directory`), the
  command MUST exit with the usage code and an error that names both
  missing inputs and the fix (`pass --feature <name-or-dir>` or pin
  `.specify/feature.json` via `zfa tdd plan <feature>`). When the pin
  resolves to a directory that does not exist, the command MUST exit with
  the usage code naming the missing pinned path.
- **FR-5 (documentation + compat)**: The subcommand usage lines and
  `--help` output MUST document `--feature` as optional (defaults to the
  pinned feature). Existing explicit-`--feature` invocations, the legacy
  flag surface, and all receipt/manifest/cycle-log formats are unchanged.

## Acceptance scenarios (measurable)

1. **Given** a repo where `.specify/feature.json` pins
   `feature_directory` to an existing feature whose spec declares a
   non-empty External Dependencies table, **when** `zfa simulate init
   test_world` runs, **then** it exits 0 and writes the world manifest at
   `specs/<pinned>/tdd/worlds/test_world.world.json` plus the certification
   receipt — byte-for-byte the same outcome as
   `zfa simulate init test_world --feature <pinned>`.
2. **Given** the pin names feature A but the invocation passes
   `--feature B` explicitly (both existing), **when** `zfa simulate init
   test_world --feature B` runs, **then** the manifest is written under
   feature B, and nothing is written under feature A.
3. **Given** no `.specify/feature.json` and no `--feature`, **when** `zfa
   simulate init test_world` runs, **then** the exit code is the usage
   code and the error names both missing inputs with the fix — and no
   world directory is created anywhere under `specs/`.
4. **Given** `.specify/feature.json` pins `specs/does-not-exist`, **when**
   `zfa simulate init test_world` runs, **then** the exit code is the
   usage code and the error names the missing pinned directory
   `specs/does-not-exist`.
5. **Given** a world already scaffolded for the pinned feature, **when**
   `zfa simulate run test_world`, `zfa simulate certify test_world`, and
   `zfa simulate verify-world test_world` each run bare (no `--feature`),
   **then** each resolves the pinned feature and produces the same
   verdict, receipts, and exit codes as its explicit-`--feature` twin.
6. **Given** the parent-level form `zfa simulate --feature <f> init
   <scenario>`, **when** it runs, **then** it resolves `<f>` exactly as
   before (regression guard — the parent flag keeps working, pin or no
   pin).

## Success criteria

### Measurable Outcomes

- **SC-001**: The exact repro from issue #1354
  (`zfa simulate init test_world`) scaffolds a world manifest whenever the
  speckit session pin names an existing declared feature — the epic #1136
  Phase A table reads GREEN without the workaround.
- **SC-002**: Every unresolvable invocation exits with the usage code and
  an error naming what was tried; no invocation ever invents a feature by
  guessing.
- **SC-003**: All pre-existing `--feature` invocations in the test suite
  pass unchanged (zero behavior drift for explicit form).

## Assumptions

- The speckit pin (`.specify/feature.json` `feature_directory`) is the
  intended "current feature" signal — it is what `zfa tdd plan`, the bone
  command, and the mock capabilities already honor.
- `--project` (when given) is the root the pin is read from, matching the
  existing semantics of the subcommands' `--project` option.
- No new flag is introduced; the fix is resolution + documentation only.
