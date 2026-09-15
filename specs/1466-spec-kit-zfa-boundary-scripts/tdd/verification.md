# TDD Verification: Spec-Kit ↔ ZFA Boundary Scripts — Acceptance Hardening (#1466)

**Feature**: 1466-spec-kit-zfa-boundary-scripts
**Template**: zuraffa-1.0
**Verified**: 2026-09-15
**Verdict**: **PASS** — every success criterion proved by an actual run on this branch. Nothing below is copied or asserted without execution; command outputs are recorded verbatim (trimmed only for repetition).

## What was verified (gate list)

1. 1466 durable suite (`run_tests.sh`): 24/24 cases + shellcheck gate
2. Mutation sensitivity (fault-injection RED): 4/4 injected faults detected
3. 1444 regression suite: 20/20 (no regression to merged behavior)
4. `dart analyze` / `dart test` / `dart format` per the branch verify protocol
5. Constraint audit: zero skill-file edits, zero production-script edits
6. Minimal-environment run (no shellcheck, no Dart SDK, no zfa, tier-3 parser): 24/24

## 1. Suite run (SC-1, SC-2, SC-3)

Command: `bash .specify/scripts/bash/tests/run_tests.sh`

```
shellcheck OK: sync-behaviors-to-tasks.sh
shellcheck OK: read-tdd-profile.sh
shellcheck OK: read-cycle-evidence.sh
shellcheck OK: tick-behavior-task.sh
  File Summary: Passed: 5/5, Failed: 0/5     (test_read_evidence.sh  E1–E5)
  File Summary: Passed: 6/6, Failed: 0/6     (test_read_profile.sh   P1–P6)
  File Summary: Passed: 6/6, Failed: 0/6     (test_sync_behaviors.sh S1–S6)
  File Summary: Passed: 7/7, Failed: 0/7     (test_tick_behavior.sh  T1–T7)
Passed: 24/24
Failed: 0/24
VERDICT: ALL GREEN
```

Actual counts: **24 cases passed, 0 failed** (SC-1 required ≥ 20 — exceeded),
shellcheck clean on all four scripts with `-x -S warning` (SC-2).

## 2. Mutation (fault-injection) evidence

Each run used a sandboxed copy (`BOUNDARY_SCRIPTS_DIR=/tmp/mutN`); the repo
working tree was never mutated.

| Mutation | Injected fault | Suite result |
|---|---|---|
| M1 → sync-behaviors-to-tasks.sh | `marker_exists()` forced `return 0` | 2/6 passed; S1, S2, S4, S6 failed — **detected** |
| M2 → read-tdd-profile.sh | `ENGINE=""` (engine lost) | 1/6 passed; P1, P2, P3, P5, P6 failed — **detected** |
| M3 → read-cycle-evidence.sh | GREEN dropped from valid phases | 3/5 passed; E1, E2 failed — **detected** |
| M4 → tick-behavior-task.sh | marker literal given trailing space | 2/7 passed; T1, T2, T4, T6, T7 failed — **detected** |

4/4 mutations detected — no test in the suite is vacuous.

## 3. Regression to merged behavior (SC-6)

Command: `bash specs/1444-spec-kit-boundary-scripts/tdd/tests/run_all_tests.sh`

```
Passed: 10/10   (acceptance A1–A10)
Failed: 0/10
Passed: 10/10   (unit U1–U10)
Failed: 0/10
Passed: 20/20
Failed: 0/20
```

## 4. Dart protocol (branch verify steps)

- **Changed Dart files vs HEAD**: none
  (`git diff --name-only HEAD -- '*.dart'` → empty).
- **`dart analyze`** (per protocol, run with the empty expansion = whole
  package): `106 issues found`, **all `info` severity, all pre-existing** in
  Dart files untouched by this branch (0 findings reference `.sh`/`.md`/`tests/`).
  No warning or error introduced by this feature — there are no Dart changes
  to introduce any.
- **`dart test` loop**: changed lib-derived test list is empty → no dart test
  targets; loop executed and completed with nothing to run (this feature is
  bash-only; its tests are the 24 bash cases above).
- **`dart format`**: `Formatted 2865 files (0 changed)` with
  `--set-exit-if-changed` → exit 0, zero formatting diffs (`git diff --stat`
  clean of format churn). Note: formatter emitted a `flutter_lints` include
  warning for `example/` — pre-existing environment condition (Flutter SDK
  not installed in this runner), unrelated to this branch.
- **Pre/post-test kernel-cache cleanup**: `rm -rf .dart_tool/test/` and
  `dart_test.kernel.*` executed before and after the protocol.

## 5. Constraint audit (SC-5, hard constraint)

```
git diff master --stat -- .specify/extensions/            → (empty)
git diff master --stat -- <four scripts> common.sh        → (empty)
```

Zero modifications to the TDD skill definition files, zero behavior edits to
the four boundary scripts or `common.sh`. The branch adds exactly:
`.specify/scripts/bash/tests/` (6 files), `.specify/scripts/bash/README.md`,
and `specs/1466-spec-kit-zfa-boundary-scripts/` (7 artifacts).

## 6. Minimal-environment proof (SC-3)

`env PATH="/usr/bin:/bin" bash .specify/scripts/bash/tests/run_tests.sh`
(no shellcheck, no Dart SDK, no zfa, no venv python → tier-3 grep/sed
parsing):

```
SKIP: shellcheck not installed — gate NOT run (install shellcheck to enable)
Passed: 24/24
Failed: 0/24
VERDICT: ALL GREEN
```

## Findings (recorded, not fixed — one-PR-per-feature)

- **F-1 (info)**: `read-tdd-profile.sh` tier-3 (grep/sed) strips one
  trailing quote from a frontmatter value, while tiers 1–2 keep it — outputs
  diverge for values ending in `"`. Suite fixtures are tier-agnostic;
  follow-up candidate for the scripts' own PR.

## Issue #1466 acceptance criteria — final status

| # | Criterion | Status | Proof |
|---|---|---|---|
| 1 | Four scripts under the spec-kit scripts dir | PROVED (pre-existing, merged #1474) | `git diff master` shows them unchanged; locations listed in README |
| 2 | shellcheck, no warnings | PROVED | gate `shellcheck -x -S warning`: 4× OK in suite run |
| 3 | Unit tests (normal/edge/error) | PROVED | 24 cases: 6/6/5/7 per script; mutation-detected |
| 4 | Callable from TDD skills (documented integration points) | PROVED | `README.md` integration map; V1 DONE |
| 5 | read-tdd-profile dart+flutter JSON | PROVED | P1 (dart), P2 (flutter, four fields), P3 (nulls) |
| 6 | sync inserts/updates markers | PROVED | S1–S6 incl. idempotency + byte-stable preservation |
| 7 | tick correct task, no corruption | PROVED | T1–T7 incl. byte-exact diff of untouched lines, mode preservation |

**Verdict: PASS.**
