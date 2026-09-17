# tdd.verify — Issue #1417 speckit scaffolding regenerable into existing repos (`zfa initialize --speckit`)

- **Verified**: 2026-09-18, this session, on `fix/1417-speckit-scaffolding-regeneration`
  (working tree, pre-push), against base `a9329746` (master)
- **Toolchain**: Dart 3.13.4 (stable) on linux_x64 (the task's "Dart 3.13+"
  floor; the repo pins `sdk: ^3.11.0`)
- **Scope**: `lib/src/commands/speckit_scaffolding.dart` (new: embedded
  constants + `SpeckitScaffoldingWriter`), `lib/src/commands/initialize_command.dart`
  (`--speckit` wiring), the new `test/commands/initialize_speckit_test.dart`,
  the re-embed tool `scripts/embed_speckit_scripts.py`, the audit tooling
  (`scripts/mutation_audit_1417.py`, `mutation-test-1417.xml`,
  `tools/run-tdd-tests-1417.sh`), and the spec artifacts under
  `.specify/specs/1417-speckit-scaffolding-regeneration/`.

## Skill execution trace (`/speckit.tdd.verify`, run verbatim)

1. **Step 0 — engine detection**: `zfa --version && test -f .zfa.json` →
   `zfa v6.3.0` printed, `.zfa.json` absent in the framework repo →
   **`ZFA_MISSING`** → per the skill, the LLM-guided fallback audit applies.
2. **Deterministic path attempted anyway** (`zfa tdd verify --feature
   1417-speckit-scaffolding-regeneration`): honest refusal —
   `gate=not_assessed, not_assessed_reason: no behavior artifacts registered`
   (the feature has no speckit-pipeline `artifacts.json`); fresh engine
   output committed at `specs/1417-speckit-scaffolding-regeneration/tdd/verification.md`.
3. **Fallback audit executed** with the real evidence below; every number in
   this file comes from a run in THIS session. Nothing is copied, stubbed,
   or back-dated.

## Verdict: PASS

## 1. Red evidence (real runs, this session)

**(a) The issue's misfire, reproduced on a fresh clone of the affected repo**
(`arrrrny/zuraffa_agent`, the exact repo shape from issue #1417: `.gitignore`
carries `.specify/*` with only `constitution.md` force-added;
`.specify/scripts/` absent):

```
$ bash .specify/scripts/bash/setup-plan.sh --json
bash: .specify/scripts/bash/setup-plan.sh: No such file or directory
EXIT=127
```

**(b) The new test suite, pre-implementation** (written against the existing
API surface; run before any fix code existed):

```
$ dart test test/commands/initialize_speckit_test.dart
00:38 +0 -8: Some tests failed.
  Expected: <0>  Actual: <1>
  stdout+stderr: ❌ Error: FormatException: Could not find an option named "--speckit".
Failing tests: U-1417-b1 … U-1417-b8 (8/8 red for exactly that reason)
```

## 2. Green evidence (real runs, this session)

```
$ dart test test/commands/initialize_speckit_test.dart
00:00 +19: All tests passed!
   (U-1417-b1..b9 acceptance + drift guard, U1–U10 writer-unit group)
```

**(a) End-to-end on the real affected repo** (fresh `zuraffa_agent` clone →
fix → the issue's Step 1 command):

```
$ dart run bin/zfa.dart initialize --speckit --root /…/zuraffa_agent
✓ Emitted .specify/scripts/bash/{common,setup-plan,check-prerequisites,setup-tasks}.sh
✓ .gitignore: appended force-include block for .specify/scripts

$ SPECIFY_FEATURE_DIRECTORY=specs/002-engine-core-loop \
    bash .specify/scripts/bash/setup-plan.sh --json
{"FEATURE_SPEC":"/…/specs/002-engine-core-loop/spec.md","IMPL_PLAN":"/…/specs/002-engine-core-loop/plan.md","FEATURE_DIR":"/…/specs/002-engine-core-loop","BRANCH":"002-engine-core-loop"}
EXIT=0
$ git check-ignore .specify/scripts/bash/setup-plan.sh; echo $?
1   (NOT ignored — the emitted helpers are trackable: ?? .specify/scripts/)
```

The stderr warning `Plan template not found` is the script's documented
non-fatal fallback (no `.specify/templates/` in the agent repo); exit 0.

**(b) No-regression on a repo with committed scaffolding** (the framework
repo itself):

```
$ dart run bin/zfa.dart initialize --speckit --root .
• Skipped .specify/scripts/bash/setup-plan.sh (already present; use --force to overwrite)
• Skipped .specify/scripts/bash/check-prerequisites.sh (already present; …)
• Skipped .specify/scripts/bash/setup-tasks.sh (already present; …)
✅ Speckit scaffolding ready: 0 created, 0 overwritten, 4 skipped.
```

`git status` confirms zero modifications under `.specify/scripts/` from the
command. `--dry-run` verified separately: announces, writes nothing (no
`.specify/` tree created).

## 3. Mutation audit (real mutants, real test runs)

Tooling note (honest): the `mutation_test` package (1.8.1) unscoped
generates 538 mutants in `speckit_scaffolding.dart` — **all inside the
embedded bash string constants** (data pinned byte-exact by drift guard
U-1417-b9; ~40s/mutant ≈ 8h of noise) — and scoped to the writer-logic
lines it generates **0** candidates (its builtin Dart rules are regex-based
and don't match this code shape; custom `<regex>` rules register — 45 rules
in verbose output — but yield no mutants; an engine quirk left unresolved
in budget). So `scripts/mutation_audit_1417.py` performs the audit
directly with the same contract (baseline-green gate, one mutant at a
time, restore-before-judge, sha256-verified restoration):

| Mutant (writer decision point) | Verdict |
| --- | --- |
| M01 `file.existsSync()` → `false` | KILLED (U1/U2) |
| M02 `existing == content` → `!=` | KILLED (U4) |
| M03 `if (!force)` → `if (force)` | KILLED (U2/U3) |
| M04 `if (!dryRun)` → `if (dryRun)` (×3) | KILLED (U5) |
| M05 `gi.existsSync()` → `false` | KILLED (U6) |
| M06 `_needsForceInclude(...)` → `false` | KILLED (U6) |
| M07 comment-skip drops `isEmpty` | SURVIVED — **equivalent mutant** (see proof) |
| M08 `rule.startsWith('!')` → `false` | KILLED (U8) |
| M09 `negated = true` → `false` | KILLED (U8) |
| M10 `needed = !negated` → `needed = negated` | KILLED (U7/U8) |
| M11 `var needed = false` → `true` | KILLED (U7) |
| M12 marker guard `contains()` → `false` | SURVIVED → **remediated**: new test U10 (user re-excludes after an append → duplicate block) added, observed killing it |
| M13 `!existing.endsWith('\n')` inverted | KILLED (U6) |

**Final: Mutants 13 — Killed 12 — Survived 0 non-equivalent — Timeouts 0 —
Restoration verified: True. AUDIT: PASS.**

M07 equivalence proof: with `line.isEmpty || line.startsWith('#')` reduced
to `line.isEmpty`, blank and comment lines reach `_excludingRules.contains(rule)`;
a blank line yields `''` and a comment line yields text starting `#` —
neither can ever equal one of `.specify/`, `.specify/*`,
`.specify/scripts`, `.specify/scripts/`, `.specify/scripts/*` (none is
empty, none starts with `#`), so `needed` is unchanged for every reachable
input. No test can kill it; excluded from the score per standard
mutation-testing practice.

M12 remediation followed the red→green loop: U10 was written from the
survivor's scenario and observed killing the mutant on the next audit pass
(killed 11 → 12).

## 4. Tool gates (real runs, this session)

```
dart analyze lib/src/commands/initialize_command.dart \
             lib/src/commands/speckit_scaffolding.dart \
             test/commands/initialize_speckit_test.dart
→ No issues found!

dart analyze            (whole repo)
→ 208 issues found      — IDENTICAL to the pre-change baseline measured at
  session start (208), i.e. zero new issues; all pre-existing
  warnings/infos in Flutter-dependent sub-packages.

dart test test/commands/initialize_dart_inplace_test.dart --preset=all
→ 00:06 +9: All tests passed!          (#393 guard pins, incl. the network
                                        bootstrap test)

dart test test/cli/bug_1360_undeclared_option_crash_test.dart \
          test/cli/cli_edge_cases_test.dart
→ 00:00 +5: All tests passed!          (option-parsing / CLI edge guards)

dart format .
→ Formatted 2945 files (0 changed)     (zero drift repo-wide; the three
                                        changed Dart files are formatted)
```

Hygiene: `.dart_tool/test/` and `$TMPDIR/dart_test.kernel.*` cleaned before
red/green runs per the task's verify recipe.

## 5. Success-criteria audit (spec SC-001..003, hard constraints)

1. **SC-001 / constraint 1 (fresh clone runs the skills' Step 1)** —
   PROVED end-to-end on the real affected repo: exit 127 before, exit 0
   with the expected JSON keys after (§2a). The skills' feature-context
   contract (`.specify/feature.json` / `SPECIFY_FEATURE_DIRECTORY`) is
   modeled exactly as the speckit-specify skill persists it (U-1417-b3).
2. **Versioned with the CLI / cannot drift (constraint 2)** — PROVED by
   construction: the four scripts are Dart string constants shipped in the
   package (same treaty as `kZuraffaSpecTemplate`), and drift guard
   U-1417-b9 compares them byte-for-byte against the canonical
   `.specify/scripts/bash/` copies. The guard PROVED itself in-session:
   it caught a leftover `&&`→`||` mutant inside a constant after a
   timeout-killed `mutation_test` run (restored via
   `scripts/embed_speckit_scripts.py`, re-verified green).
3. **Constraint 3 (no breakage of committed scaffolding)** — PROVED: the
   framework-repo run reports 4 skipped / 0 overwritten and leaves the
   tree unchanged (U-1417-b4, U4); `--force` overwrite covered by
   U-1417-b5 / U3.
4. **Constraint 4 (`.gitignore` handled)** — PROVED: repos with a
   `.specify/*` rule get the idempotent force-include block (U-1417-b6,
   U6, U10), repos without `.specify` rules are untouched (U-1417-b7, U7),
   pre-negated repos are respected (U8), and no `.gitignore` is never
   created (U9). Verified on the real repo: `git check-ignore` → 1 after
   the fix.
5. **Constitution I (CLI-built only)** — PRESERVED: the scripts ship as
   CLI-owned embedded content (`SpeckitScaffoldingWriter`); nothing is
   hand-scaffolded by the fix; the framework repo's own tracked copies are
   the drift-guard source of truth.

## 6. Coverage summary (test-list → verdict)

| id | verdict |
| --- | --- |
| U-1417-b1 parser flag | GREEN |
| U-1417-b2 emission | GREEN |
| U-1417-b3 E2E setup-plan.sh JSON | GREEN |
| U-1417-b4 no-clobber idempotency | GREEN |
| U-1417-b5 --force overwrite | GREEN |
| U-1417-b6 gitignore block once | GREEN |
| U-1417-b7 gitignore untouched | GREEN |
| U-1417-b8 no-pubspec surgical | GREEN |
| U-1417-b9 drift guard | GREEN (and proved itself live) |
| U1–U10 writer unit (incl. mutation remediation U10) | GREEN |

**Gate decision: PASS** — the suite is green, all non-equivalent mutants
killed, restoration verified, and the issue's misfire is reproduced-red and
proven-green end-to-end in this session.

## Remediation tasks

None outstanding. (M12's remediation task "strengthen the suite to kill the
marker-guard mutant" was completed in-loop via U10; M07 is a proven
equivalent mutant, documented above.)
