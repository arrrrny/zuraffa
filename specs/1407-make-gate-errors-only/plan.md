# Implementation Plan: make gates on errors only — warnings are non-blocking and consistent across lanes

**Branch**: `feat/1407-make-gate-errors-only` | **Date**: 2026-09-11 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/1407-make-gate-errors-only/spec.md`

## Summary

`zfa tdd make` grades a failed terminal `build` step through the #737
per-behavior guard. The build command's analyze gate (issue #1035) refuses
the tree on errors OR warnings, so a pre-existing engine-lane warning
(0 errors + 1 warning) makes the skin lane's make stop
`outcome=generation-error` while the engine lane's own green receipt
accepted the same warning — cross-lane warning coupling (issue #1407). Fix
shape: keep the build step and its gate untouched (the dart analyze
invocation and what it reports are unchanged) and add an **errors-only
re-grade in the make** — when the plan's terminal `build` step fails, the
make reads the gate's own refusal verdict from the captured output
(`dart analyze reported <E> error(s) and <W> warning(s)`), cross-checks it
through the shared analyzer line-format parser
(`BuildCommand.countAnalyzerIssues`, the single #1035 contract), and when
the verdict is 0 errors + ≥1 warning, logs the warnings with a
non-blocking verdict and proceeds through the normal make flow
(post-generation target test → suite guard → green evidence). Analyzer
errors keep the byte-identical #942 refusal. A project opts back into the
legacy warnings-blocking strictness via the TDD profile's machine-readable
Keys block (`analyze-gate: warnings-blocking`); every other profile state
defaults to errors-only.

## Technical Context

**Language/Version**: Dart 3.13 stable (pubspec `sdk: ^3.11.0`), pure-Dart root package

**Primary Dependencies**: `package:test` ^1.25.0, `package:path`, `package:args` — the TDD plugin lives under `lib/src/plugins/tdd/`

**Storage**: append-only markdown evidence (`tdd/cycle-log.md`) + registry records (`tdd/artifacts.json`) + TDD profile (`.specify/memory/tdd-profile.md`)

**Testing**: `dart test` (per `.specify/memory/tdd-profile.md`); feature scope `dart test test/plugins/tdd/bug_1407_make_gate_errors_only_test.dart`; analysis `dart analyze` on the changed files

**Target Platform**: CLI (macOS/Linux/Windows dev machines)

**Project Type**: CLI code generator (zuraffa) with a spec-kit TDD extension

**Performance Goals**: the re-grade adds one regex match + one shared-parser pass over the already-captured build output on the failure path only — no cost on the happy path

**Constraints**: fix scoped to `lib/src/plugins/tdd/commands/make_command.dart` (the issue's hard constraint); the build command's gate, the pipeline runner, verify-red, and the gen pipeline are read-only from this feature

**Scale/Scope**: 1 source file touched + 1 new test suite; no CLI surface change (the gate is a profile-configured policy, not a flag)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

The repo's operative contracts this plan must honor (AGENTS.md + the code's
documented invariants):

- **Test-first**: every behavior lands red-first via the tdd loop's own
  machinery (`tdd/test-list.md` drives the suite; red evidence recorded
  before the fix lands).
- **Errors-are-an-API**: the non-blocking path prints its own verdict line
  naming the counts, the policy, and the issue; the refusal paths are
  byte-identical to today.
- **Safe-failure, never a silent pass**: the gate engages only on the
  build gate's own 0-error refusal verdict, cross-checked through the
  shared parser; a red target test after generation still stops honestly;
  disagreements between the gate message and the shared parser keep the
  honest stop.
- **One format contract**: the analyzer line format is read only through
  `BuildCommand.countAnalyzerIssues`/`analyzeReportsError` (the #1035
  single contract); the gate's refusal verdict is read from the build
  command's own message (the single writer).

**Verdict**: PASS (no violations).

## Project Structure

### Documentation (this feature)

```text
specs/1407-make-gate-errors-only/
├── spec.md              # Feature specification (4 ACs, edge cases, FRs, SCs)
├── plan.md              # This file
├── tasks.md             # Dependency-ordered task list (MVP-first)
└── tdd/
    ├── test-list.md     # One behavior per line, traced to the ACs
    └── verification.md  # Test-first + mutation evidence (post-implement)
```

### Source Code (repository root)

```text
lib/src/plugins/tdd/commands/
└── make_command.dart        # THE fix surface (hard constraint):
                             #   - _analyzeGateRefusalPattern + _isWarningsOnlyBuildGateRefusal
                             #     (gate-verdict attribution, shared-parser cross-check)
                             #   - _logWarningsOnlyGateRefusal (verdict + capped warning lines)
                             #   - _profileWarningsBlocking (AC4 opt-in reader)
                             #   - the errors-only branch in the !pipelineResult.completed block
test/plugins/tdd/
└── bug_1407_make_gate_errors_only_test.dart  # the behaviors (red-first)
```

## Design Decisions

### D1 — Where the gate lives: the make's step grading, not the build command

The hard constraint scopes the fix to `make_command.dart`. The build
command's analyze gate keeps refusing on warnings (its #1035 contract is
not this issue's to change); the make stops treating that refusal as a
generation verdict when the verdict is warnings-only. This is "only how
make interprets it" — the make already interprets the same output through
`BuildCommand.analyzeReportsError` in the #942 gate, so the errors-only
re-grade is the same seam, one verdict earlier in the grading order.

### D2 — Attribution: the gate's own message + the shared parser

The make must distinguish "the build failed because the analyze gate
refused warnings" from "the build failed for any other reason". The gate
message (`❌ dart analyze reported <E> error(s) and <W> warning(s) —
generated code does not compile cleanly.`) has exactly one writer
(build_command's analyze gate) and carries the counts the gate decided on.
Attribution requires: (a) the failed step IS the plan's terminal build
step (the same precondition the #737 tolerance uses — per-behavior by
construction); (b) the message present with E==0, W>=1; (c) the shared
parser (`BuildCommand.countAnalyzerIssues`) finds 0 `error -` lines in the
raw output — a disagreement keeps the honest stop (safe-failure). Build
failures without the message reach the existing tolerance family
unchanged.

### D3 — Grading order: the errors-only gate runs BEFORE the #737/#942 tolerance

A warnings-only refusal is fully non-blocking — it must not reach the
tolerance, whose target-test requirement would still grade the make on a
red test (the real-world W3 refusal). The gate branch falls through to the
normal flow (fresh post-generation target test, suite guard, green
evidence). Errors, non-gate build failures, non-terminal/non-build steps,
and the warnings-blocking opt-in all skip the branch and hit the existing
grading paths byte-identically.

### D4 — Outcome vocabulary unchanged

The non-blocking path ends in plain `outcome=green` (the make genuinely
passed: generation ran, the target test passes, the guard is clean). No
new outcome token is minted — the #942 `green-with-failed-build` label
stays reserved for genuinely failed builds the guard tolerates, which a
mere warning no longer produces. The green evidence's `generation` block
records the steps as captured (the same shape the tolerated path already
records).

### D5 — AC4 opt-in: profile Keys block, `analyze-gate:` key

The TDD profile (`.specify/memory/tdd-profile.md`) is the tdd plugin's
existing machine-readable config surface; its Keys block already carries
`runner/single/suite/file/coverage`. The optional `analyze-gate:` key
reads `warnings-blocking` (case-insensitive) to restore the legacy
strictness; absence, `errors-only`, any unrecognized value, or a
missing/unreadable profile defaults to errors-only (fail-open to the fix,
never to the legacy refusal). The reader follows the loader conventions of
`SingleTestRunner` (Keys block first, legacy frontmatter fallback) but
lives in make_command.dart per the hard constraint.

## User Story → Design mapping

| US | Design | Surface |
| -- | ------ | ------- |
| US1 (warnings never fail a make) | D1, D2, D3, D4 | errors-only branch + logging in make_command.dart |
| US2 (same strictness across lanes/transitions) | D1, D3 | the branch lives in the one shared `!pipelineResult.completed` grading block every lane's make runs |
| US3 (profile opt-in) | D5 | `_profileWarningsBlocking` in make_command.dart |

## Risks / Trade-offs

- **[R1] Gate message coupling** — the regex reads build_command's message
  text. Mitigation: the message is a stable, single-writer contract; the
  shared-parser cross-check bounds the damage of any drift (disagreement →
  honest stop, never a false pass); the tests pin both sides.
- **[R2] A warnings-only refusal proceeding with a genuinely broken tree** —
  the gate message says 0 errors, but suppose the tree is broken anyway.
  Mitigation: the normal flow's own safe-failure net catches it — the
  post-generation target test compiles and exercises the subject, the
  suite guard diffs the baseline; a broken tree cannot reach green.
- **[R3] Evidence shape** — the green entry records a build step whose
  exit was non-zero. Mitigation: the #737 tolerated path already records
  this shape; the evidence schema is unchanged.
