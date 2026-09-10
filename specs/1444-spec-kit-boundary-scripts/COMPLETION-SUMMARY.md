# Feature 1444 Completion Summary

**Date**: 2026-09-10  
**Status**: Complete - all 20 behaviors GREEN (A1-A10 + U1-U10)  
**Remaining**: none

## What Was Accomplished

Four boundary scripts give the Spec-Kit TDD loop deterministic file operations
instead of LLM-driven markdown edits:

1. **U1 / A1-A3**: `sync-behaviors-to-tasks.sh` - inserts or updates
   `[behavior: <id>]` markers in `tasks.md` from `test-list.md`, grouping by ID
   prefix into Acceptance / Unit / Characterization sections.
2. **U2 / A4-A5**: `read-tdd-profile.sh` - emits the detected test engine and
   commands from the profile's YAML frontmatter.
3. **U3 / A6-A7**: `read-cycle-evidence.sh` - parses `cycle-log.md` into
   structured evidence entries.
4. **U4 / A8-A10**: `tick-behavior-task.sh` - flips a single behavior's checkbox
   from `[ ]` to `[x]`.

All scripts share the remaining unit behaviors: the three-tier parser cascade
(**U5**), `--json` output (**U6**), `jq --arg` JSON construction (**U7**),
`set -euo pipefail` (**U8**), location under `.specify/scripts/bash/` (**U9**),
and helpers sourced from `common.sh` (**U10**).

**Evidence**: the aggregate suite passing 20/20.

```bash
bash specs/1444-spec-kit-boundary-scripts/tdd/tests/run_all_tests.sh
# Result: Acceptance 10/10, Unit 10/10, aggregate Passed: 20/20
```

### Implementation Details

#### Scripts
- `.specify/scripts/bash/sync-behaviors-to-tasks.sh` (403 lines)
- `.specify/scripts/bash/read-tdd-profile.sh` (186 lines)
- `.specify/scripts/bash/read-cycle-evidence.sh` (367 lines)
- `.specify/scripts/bash/tick-behavior-task.sh` (243 lines)

#### Test Infrastructure
- `specs/1444-spec-kit-boundary-scripts/tdd/tests/acceptance_tests.sh` (540 lines) - A1-A10
- `specs/1444-spec-kit-boundary-scripts/tdd/tests/unit_tests.sh` (297 lines) - U1-U10
- `specs/1444-spec-kit-boundary-scripts/tdd/tests/run_all_tests.sh` (85 lines) - drives both and aggregates
- `specs/1444-spec-kit-boundary-scripts/tdd/tests/test_A1.sh` (61 lines) - standalone A1 reproduction

#### Documentation
- `specs/1444-spec-kit-boundary-scripts/tdd/test-list.md` - 20 behaviors traced to criteria, with per-behavior evidence
- `specs/1444-spec-kit-boundary-scripts/tdd/cycle-log.md` - RED/GREEN/REFACTOR entries in the format `read-cycle-evidence.sh` parses

### Earlier Path-Resolution Blocker (resolved)

An earlier revision of this summary recorded that the acceptance tests could not
run because the scripts resolved their inputs through `get_feature_paths()` and
therefore could not be pointed at a temp fixture directory. That was fixed by
giving every script the documented positional arguments
(`<cycle-log-path>`, `<tdd-profile-path>`, `<test-list-path> <tasks-path>`,
`<tasks-path> --behavior <id>`), keeping `get_feature_paths()` only as the
fallback when the argument is omitted. The acceptance suite now runs against
isolated fixtures with no `.specify/` mock and no dependency on the ambient
feature directory.

## Verification Commands

```bash
# Full suite (both tiers of behaviors)
bash specs/1444-spec-kit-boundary-scripts/tdd/tests/run_all_tests.sh

# Unit behaviors only
bash specs/1444-spec-kit-boundary-scripts/tdd/tests/unit_tests.sh

# Acceptance behaviors only
bash specs/1444-spec-kit-boundary-scripts/tdd/tests/acceptance_tests.sh

# Parser cascade without python3/yq on PATH
PATH=/tmp/nopy-bin bash .specify/scripts/bash/read-cycle-evidence.sh \
    specs/1444-spec-kit-boundary-scripts/tdd/cycle-log.md --json
```

## Honest Assessment

**What's working**: all 20 behaviors are implemented and asserted. Every script
was additionally executed with `python3` and `yq` removed from `PATH`; the shell
tiers produced output identical to the python3 tiers, including malformed-entry
warnings on stderr and an inert injection payload for `tick-behavior-task.sh`.
`unit_tests.sh` checks the cascade statically (U5); the `PATH` runs check it
behaviourally.

**What's partial**: `read-tdd-profile.sh` reads the flat frontmatter its contract
specifies (`engine`, `test_command`, optional `verify_command`/`plan_command`).
The repository's `.specify/memory/tdd-profile.md` is owned by the `tdd` extension
and uses a different, nested schema — `ecosystems:` / `default:` / `stacks:` with
per-stack `runner`, `single`, `file`, `suite`, `coverage`, as documented in
`.specify/extensions/tdd/templates/tdd-stack-profile.md:95-130` — and today
carries no frontmatter at all. Pointing the script at it therefore reports
"No YAML frontmatter found", which is the contract's documented behaviour for a
file without frontmatter.

That file was deliberately **not** rewritten here: adding the flat keys would
conflict with the extension's nested schema and break `zfa tdd` /
`/speckit.tdd.setup`, which read the same path. The schema mismatch between this
PR's contract and the extension's profile format needs a decision by the
maintainer — either reconcile the two schemas, or give this script its own file.
