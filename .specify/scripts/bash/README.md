# Spec-Kit ↔ ZFA Boundary Scripts

Deterministic bash replacements for the file operations that the spec-kit TDD
skills would otherwise perform on shared markdown by LLM freehand. Issue
#1466: every read/parse/tick at the boundary between spec-kit and zfa goes
through a script, not through an agent rewriting a file.

The four scripts live in this directory (`​.specify/scripts/bash/`), use
`set -euo pipefail`, source `common.sh` for shared helpers (feature-path
resolution, repo-root detection), parse with the **three-tier cascade
(jq → python3 → grep/sed)** — first available tier wins — and emit JSON when
invoked with `--json` (built via `jq --arg` when jq is present, escaped
string interpolation otherwise). Text mode is the default.

**Constraint note:** the TDD skill definition files
(`.specify/extensions/tdd/commands/*.md`) are intentionally NOT modified.
This README is the documented integration contract: when wiring a skill step
to the boundary (or performing that step as an agent), call the script
exactly as specified here instead of editing the markdown by hand.

## Script ↔ Skill-Step Integration Map

| TDD skill step (operation on shared markdown) | Replacing script | Typical call |
|---|---|---|
| `/speckit.tdd.plan` Step 3 — sync `[behavior: <id>]` markers from test-list.md into tasks.md | `sync-behaviors-to-tasks.sh` | `sync-behaviors-to-tasks.sh "$FEATURE_DIR/tdd/test-list.md" "$FEATURE_DIR/tasks.md" --json` |
| `/speckit.tdd.setup` Phase 2/3 — read the recorded stack profile (engine + commands) | `read-tdd-profile.sh` | `read-tdd-profile.sh .specify/memory/tdd-profile.md --json` |
| `/speckit.tdd.run` Step 3 — read red/green evidence from cycle-log.md when handling stops | `read-cycle-evidence.sh` | `read-cycle-evidence.sh "$FEATURE_DIR/tdd/cycle-log.md" --json` |
| `/speckit.tdd.run` Step 4 — tick the tasks.md task of each behavior driven to done | `tick-behavior-task.sh` | `tick-behavior-task.sh "$FEATURE_DIR/tasks.md" --behavior <id> --json` |
| `/speckit.tdd.verify` — gather evidence for the audit; tick remediation tasks | `read-cycle-evidence.sh` + `tick-behavior-task.sh` | see per-script contracts below |

## sync-behaviors-to-tasks.sh

Inserts missing `[behavior: <id>]` task markers into tasks.md from the
behavior definitions (`**<ID>**: <description>` lines) in test-list.md.

```
Usage: sync-behaviors-to-tasks.sh <test-list-path> <tasks-path> [--json]
```

- **Arguments**: `<test-list-path>` (behavior definitions), `<tasks-path>`
  (file to update). When omitted, both fall back to the feature directory
  resolved from `SPECIFY_FEATURE_DIRECTORY` / `.specify/feature.json`
  (`$FEATURE_DIR/tdd/test-list.md`, `$FEATURE_DIR/tasks.md`).
- **Grouping**: markers are appended into `## Acceptance Behaviors` /
  `## Unit Behaviors` / `## Characterization Behaviors` sections (by ID
  prefix A/U/C), creating missing sections at the end of the file; existing
  sections receive markers after their last content line.
- **Safety**: writes are atomic (temp file + `mv`, permission bits
  preserved); duplicate IDs in test-list.md abort with exit 2 before any
  write; malformed IDs are skipped with a stderr warning; existing marker
  lines are never rewritten.
- **JSON success**: `{"status":"success","behaviors_added":N,"behaviors":["A1",…]}`
  (`behaviors_added: 0` when everything is already present — the call is
  idempotent).
- **Errors**: exit 1 missing input file; exit 2 duplicate behavior ID. JSON
  mode also emits `{"status":"error","error":"…"}` on stdout.

## read-tdd-profile.sh

Parses the YAML frontmatter of tdd-profile.md and emits the test engine
configuration. This is how `/speckit.tdd.setup` output is consumed
deterministically by later steps.

```
Usage: read-tdd-profile.sh <tdd-profile-path> [--json]
```

- **Argument**: `<tdd-profile-path>`. Default:
  `.specify/memory/tdd-profile.md` (repo root).
- **Required frontmatter fields**: `engine`, `test_command`. Optional:
  `verify_command`, `plan_command`.
- **JSON success** (dart engine):
  `{"engine":"dart","test_command":"dart test","verify_command":null,"plan_command":null}`
  — optional fields are `null` when absent, full strings when present
  (flutter profile:
  `{"engine":"flutter","test_command":"flutter test",…}`).
- **Text success**: `Engine: …`, `Test Command: …`,
  `Verify Command: (not configured)` when unset.
- **Errors**: exit 1 — file missing, no frontmatter, or a missing required
  field, each with the reason on stderr.

## read-cycle-evidence.sh

Parses cycle-log.md into structured evidence entries. This is how stop
handling and `/speckit.tdd.verify` audits read red/green evidence without
freehand interpretation.

```
Usage: read-cycle-evidence.sh <cycle-log-path> [--json]
```

- **Argument**: `<cycle-log-path>`. Default:
  `$FEATURE_DIR/tdd/cycle-log.md` via the feature-path fallback.
- **Recognized format**: entries are `## <YYYY-MM-DD> <HH:MM[:SS]> - <PHASE> -
  <behavior-id>` headings (PHASE ∈ RED | GREEN | REFACTOR) with an
  `Evidence:` block, separated by `---` or the next `##` heading. Narrative
  headings without a timestamp (e.g. `## Baseline`) are ignored.
- **JSON success**:
  `{"evidence":[{"phase":"RED","behavior_id":"U9","timestamp":"2026-09-15T10:00:00","evidence_text":"…"}]}`
  — malformed entries are skipped with a `WARNING: Skipping malformed entry`
  on stderr instead of failing the read.
- **Text success**: `Found N evidence entries:` followed by one rendered
  block per entry.
- **Errors**: exit 1 — file missing or unreadable.

## tick-behavior-task.sh

Marks exactly one `[behavior: <id>]` task as done in tasks.md — the
deterministic form of "tick the tasks.md task" in `/speckit.tdd.run` Step 4
and `/speckit.tdd.verify` remediation.

```
Usage: tick-behavior-task.sh <tasks-path> --behavior <id> [--json]
```

- **Arguments**: `<tasks-path>` (default: `$FEATURE_DIR/tasks.md` via the
  feature-path fallback); `--behavior <id>` is required.
- **Behavior**: the first line containing the fixed string
  `[behavior: <id>]` is flipped from `- [ ]` to `- [x]`; all other lines stay
  byte-identical; the write is atomic with permission bits preserved.
- **JSON success**: `{"status":"success","behavior_id":"U1","message":"Task ticked"}`;
  re-ticking an already-done behavior exits 0 with
  `{"status":"already_done",…}` and rewrites nothing.
- **Errors**: exit 1 — behavior not found (`{"status":"not_found",…}` in
  JSON mode), tasks.md missing, or `--behavior` omitted/empty (usage on
  stderr). Duplicate markers tick the first occurrence and print a warning
  on stderr.

## Feature-path fallback (shared)

When the positional file arguments are omitted, `common.sh` resolves the
active feature directory from `SPECIFY_FEATURE_DIRECTORY` if set, otherwise
from `.specify/feature.json` (`feature_directory` key). Passing explicit
paths always wins — the test suite does exactly that.

## Test suite

The suite for these scripts lives in [`tests/`](./tests/):

```bash
bash .specify/scripts/bash/tests/run_tests.sh
```

The runner (a) gates all four scripts through `shellcheck -x -S warning`
(skipped with a loud notice when shellcheck is absent) and (b) executes every
`tests/test_*.sh`, printing per-case results and one aggregate
`Passed: N/N` line; it exits non-zero on any failure. Coverage: normal
input, edge cases (idempotency, duplicates, malformed ids, duplicate
markers, permission-bit preservation) and error conditions (missing files,
missing flags, unknown ids) for all four scripts, plus both `dart` and
`flutter` engine profiles. Point `BOUNDARY_SCRIPTS_DIR` at a sandbox copy to
run the suite against a mutated script (fault-injection sensitivity check).

History: the scripts were introduced by feature 1444 (PR #1474); feature
1466 (#1466) added the durable test suite, the shellcheck gate, and this
integration documentation.
