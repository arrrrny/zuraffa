# TDD Verification — CORPUS-WALK (feature 076, epic #1017)

**Date**: 2026-09-05
**Suite baseline**: `dart test test/commands/` (feature scope) + full-repo chunked run
**Result**: feature scope **175 tests pass, 0 fail** (includes this feature's 43 + the
existing command suite). Full repository chunked fast tier: **69/70 chunks "All tests
passed", ~2900 net green**; the one red chunk (`test/plugins/tdd/commands`, U-V4)
passes **157/157 standalone** on re-run — the repo's documented concurrent-CWD flake
class (issue #506), unrelated to this change (the corpus family is a different
subsystem; the single test also passes alone).

## Verify path

`zfa --version && test -f .zfa.json` -> `ZFA_MISSING` (this repo is the framework,
not a driven app) — so `/speckit.tdd.verify` took its **documented fallback path**
(the LLM-guided audit per `.specify/extensions/tdd/commands/speckit.tdd.verify.md`):
test-first evidence, cycle-log red evidence, test-smell rubric, deliberate-mutant
sampling (no mutation tool wired — `.specify/memory/tdd-profile.md`), and
criteria-to-tests traceability. This file is that audit's product.

## Red → green evidence (042-style honesty)

- **Red** (tests written first against the not-yet-existing commands):
  `dart test test/commands/corpus_catalog_command_test.dart \
    test/commands/corpus_run_walk_command_test.dart \
    test/commands/corpus_ledger_command_test.dart`
  → **+0 passed / -43 failed**, every failure the same shape: `zfa corpus` only
  knows `import` (`Could not find an option named "--project"`); no catalog/run/
  ledger commands, no CORE/SKIN classification, no committed walk ledger anywhere
  in the repo (the epic's RED step 2, reproduced).
- **Green**: after implementation, the same three files → **43 passed / 0 failed**
  (13 catalog + 16 run + 14 ledger). Reproduced 19 consecutive times while hunting
  a transient (below). Existing corpus family re-run green: `corpus_command_test`
  (import, spec 050) + `setup_corpus_specs_test` — no regressions from the modified
  command family.
- Defects the red tests caught during the green phase are in
  `tdd/cycle-log.md` (wrong exception class caught — exitCode leaked 0; empty-catalog
  misfire unreachable; stale catalog hash hiding drift).

## 1. Coverage

Every implemented unit has at least one passing test through the real CLI entry
point (`CliRunner.runCapturing`): the classifier (CORE/SKIN/tie), the catalog store
(write/read/preserve/corrupt), the walker (verdict mapping, not-ready, walk-time
hashing, persistence), the budget parser, the ledger store (baseline/read/corrupt),
and the diff (regression/renewed/added/removed). The per-feature spawns go through
the repo's canonical scripted fake-zfa pattern (`--zfa-bin`), the same contract spec
049/051 tests use. Coverage tooling not invoked (the repo's tdd-profile declares
coverage opt-in); test mapping is complete, but coverage is unmeasured.

## 2. Mutation (deliberate-mutant sampling — 3 sampled, 3 killed)

No mutation tool is wired (`.specify/memory/tdd-profile.md`), so per the rubric's
"without a mutation tool" path, the highest-risk behaviors were sampled with
deliberate mutants (applied → tests run → restored → suite re-run green):

| # | Mutant (file, change) | Expected violated behavior | Result |
|---|-----------------------|----------------------------|--------|
| 1 | `corpus_command.dart` — budget comparison inverted (`used > budget` -> `used < budget`, exit-code + result-token swapped) | FR-004 budget gate | **KILLED** — 3 failures (A4 within/over/default-budget tests) |
| 2 | `corpus_walk_ledger.dart` — regression detection disabled (`if (false && wasGreen && !isGreen)`) | FR-008 regression gate | **KILLED** — 3 failures (A4 green→partial, green→blocked, new-feature-breaks-contract) |
| 3 | `corpus_catalog.dart` — classifier tie-break inverted (`skin > core` -> `skin >= core`) | FR-001 ties resolve CORE | **KILLED** — 1 failure (A2 neutral-falls-CORE) |

Each restore was verified by re-running the scoped suites green before moving on.
Not sampled: the catalog's `--source` walk, walk persistence JSON, ledger renewal
path (each has direct assertions in the green suite but no deliberate mutant —
honest gap; the three sampled behaviors are the ones the epic's exit criteria name).

## 3. Success criteria — PROVED vs not (issue #592 style)

| Criterion | Status | Evidence |
|---|---|---|
| SC-001 catalog classifies CORE/SKIN with preserved edits, deterministic output | **PROVED at fixture level** | A2/A3/A4/A5 groups (13 tests): engine spec -> CORE, presentation spec -> SKIN, neutral -> CORE, manual edit preserved across regeneration, `--reclassify` recomputes, byte-stable JSON except `generated_at` |
| SC-002 walk finishes with `green: N \| partial: M \| blocked: K` under the budget | **PROVED at fixture level** | A2/A3/A4 groups (16 tests): walk continues past failures, exact tally line, exit 0 iff M+K <= budget (default 5), over-budget names the breach with exit 1 |
| SC-003 ledger committed; subsequent runs are diffs; contract breaks are CI failures | **PROVED at fixture level** | A2-A6 groups (14 tests): baseline writes + exit 0, unchanged -> clean, green→partial/blocked -> exit 1 with the regression named, removed-green -> exit 1, spec-evolves-stays-green -> renewed, corrupt -> exit 2 `--> fix:` |
| SC-004 all behaviors red-to-green | **PROVED** | +0/-43 red recorded in cycle-log (the commands were absent); 43/43 green after |
| Epic exit criterion: walk the REAL ZikZak 120-spec corpus (M+K <= 5) | **NOT PROVED** | The real zik_zak corpus (the driven app's extracted specs) is not present in this environment. The machinery is proved against scripted fixtures; the driven-app repo owns the real run (`zfa corpus import <zik_zak specs> && zfa corpus catalog --target zik_zak && zfa corpus run --target zik_zak && zfa corpus ledger --target zik_zak`), with the ledger committed in THAT repo per the contract. |

## 4. Verification commands and actual results

```bash
dart analyze lib test --no-fatal-warnings      # 314 issues (infos+warnings), 0 errors —
                                               # byte-identical count to master baseline
                                               # (verified via git stash on clean master);
                                               # zero findings in this feature's files
dart test test/commands --exclude-tags flutter # +175: All tests passed! (2m18s)
dart test test/commands/corpus_{catalog,run_walk,ledger}_command_test.dart
                                               # +43: All tests passed! (19 consecutive runs)
tools/run_tests_chunked.sh                     # 69/70 chunks "All tests passed", ~2900 net
                                               # green; 1 transient (U-V4) that passes
                                               # standalone (157/157 chunk re-run)
dart format .                                  # 0 changed after the initial 7-file format
git diff --stat                                # no formatting drift
```

Notes recorded honestly:

- `tools/run_tests_chunked.sh` does not execute `test/commands` at all — the folder
  (42 files on master, > the 40-file threshold) has no test-carrying subdirectories,
  so the chunker drops it. This is PRE-EXISTING (verified: the dry-run chunk list on
  clean master also omits it); `test/commands` was therefore run explicitly, above.
- One transient observed twice during the mutant-restore window (the run-command
  guidance test reported exitCode 0 instead of 2); 19 consecutive green re-runs plus
  the full-folder 175/175 could not reproduce it. Recorded as the repo's documented
  concurrent-kernel/CWD flake class (issue #506), not absorbed silently.

## 5. Test-smell pass (rubric catalogue, cold read)

No `HIGH` findings: every test asserts observable behavior (exit codes, machine
summary lines, committed JSON on disk, the spawned argv log) through the real entry
point; no tautologies (the fake zfa is a scripted collaborator, not the subject —
the subject is the walk/classifier/ledger logic); no conditional assertions; no
skips. `LOW`/`MED`: the fixture duplicates the repo's `CorpusFixture` bash-fake
conventions by design (the tdd helper lives under `test/plugins/tdd/helpers/` and
carries manifest/specs assumptions this feature's tests don't share); noted as
acceptable duplication, not bypass of a recorded helper.

## 6. Traceability

`tdd/test-list.md` maps A1-A38 (acceptance) and U1-U9 (unit) to the three test
files; every listed test exists and runs (the 43 green), and every acceptance
scenario in `spec.md` (US1: 4, US2: 5, US3: 6) reaches at least one test through
the real CLI entry point. Both directions checked: no test traces to a
non-existent criterion; no criterion is untested.
