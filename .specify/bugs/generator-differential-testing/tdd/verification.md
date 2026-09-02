feature: generator-differential-testing (vision #805 slice v0, branch mode)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: bd535c07
behaviors: 8
proven: 8
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 8
criteria_covered: 8
mutation_score: 100 # scope: changed branch, 4 deliberate mutants, all caught, all restored
mutants_survived: 0
suite: differential 56/56; chunked fast suite 67 chunks 62 PASS / 5 SKIP / 0 FAIL; tdd tree re-run 549 tests (root-level files the chunker does not split); zero new analyzer issues; format zero-diff
---

# TDD Verification: #805 generator differential testing — same spec, two refs, behavioral diff

**Verdict: PASS.** The decisive reason: the gate ran the shipped
regression corpus through the REAL generator at two REAL git refs and
produced the issue's named outcome classes end-to-end — a healthy pair
reported `result=match` (exit 0) on all three entries, a synthetic
#744-class broken ref was failed with the exact
`gen U2: hang vs complete` line (exit 1), and the historical #751
divergence was replayed from a real sha (`make U1: failed vs complete`,
exit 1) — with the full fast suite green and four deliberate mutants
all caught.

Record source note: issue #805 is a VISION item (Pillar A of #804,
"Proof-carrying generation") and has no `.specify/bugs/` record on any
branch; the authoritative input was the GitHub issue body of
[arrrrny/zuraffa#805]("[VISION] Generator differential testing") plus
the three incident bodies it names (#744 fixed by #748, #751, #752).

## Gap (from issue, confirmed in source)

The repo had no behavioral differential capability anywhere: `git grep
-i differential` over `origin/master` matched only `.specify/` prose,
and no `proof` command existed. The corpus harness (spec 051) drives
ONE checkout's features through `tdd run`/`tdd verify`; nothing
compared two generator REFS. Three real regressions had reached users
in this exact blind spot (#744's gen hang regression from #738, #751's
`--suite-baseline` flag mismatch, #752's cached-baseline make break) —
each was caught by a user-reported bug, not by a gate, which is the
precise cost the vision item prices ("the cheapest possible insurance
on generator refactors").

## Remediation (issue slice v0, mapped)

1. **Corpus runner against two git refs** — `DifferentialRefRunner`
   (`lib/src/plugins/tdd/services/differential_ref_runner.dart`)
   resolves each ref (`git rev-parse --verify <ref>^{commit}`),
   materializes it as a detached worktree (`git worktree add --detach`,
   the #049/#051 injectable-git pattern), resolves its dependencies
   (`dart pub get --no-example`), and drives each entry's steps through
   `dart <worktree>/bin/zfa.dart ...` into a fresh per-(entry, ref)
   scratch project copied from the entry's `project/` scaffold.
2. **Result-vector compare** — `differential_vector.dart`: one
   `EntryVector` per (entry, ref) holds one `StepVector` per step
   (exit code, outcome class `complete|failed|hang`, machine token from
   gen's JSON verdict #840 / make's `outcome=` line / the `result=`
   contract, dart-test `+pass -fail` counters) plus the sorted artifact
   inventory. `compareEntryVectors` renders step/count/artifact
   findings; bytes are deliberately never compared ("behavioral diff …
   artifact inventory — not bytes").
3. **One regression entry per past incident** — `corpus/regression/`:
   `u2-flow` (#744: gen U1 → gen U2 → `dart test test/tdd`; the second
   gen is the recorded hang site), `make-suite-baseline-flag` (#751:
   gen → verify-red → `make --suite-baseline` on a green cached
   baseline), `make-baseline-cache` (#752: same shape on a baseline
   with one pre-existing failure). Scaffolds are portable by design:
   steps rebuild project state inside the scratch (a frozen
   `artifacts.json` would embed absolute build paths and break the
   registry's ownership check on copy).
4. **CI gate** — `.github/workflows/generator-differential.yml`:
   generator-touching PRs (`lib/**`, `bin/**`, `corpus/**`) run
   `zfa tdd corpus differential --from "origin/<base>" --to HEAD` under
   `timeout-minutes: 20` with `fetch-depth: 0`.
5. **Honesty rules** — a step killed at the budget records `hang` (the
   #744 class), never a runner misfire; missing corpus / corrupt entry
   / unknown ref / setup failure are distinct runner-error classes
   (exit 2); every invocation ends with the machine summary line
   `differential: entries= compared= differing= errors= from= to=
   result=`; worktrees are removed in a `finally` and cleanup can never
   mask the verdict.

## Test-first evidence

- **RED (pre-implementation):** five test files pinned the absent
  surface (`test/plugins/tdd/models/differential_vector_test.dart`,
  `services/differential_corpus_test.dart`,
  `services/differential_ref_runner_test.dart`,
  `commands/corpus_differential_command_test.dart`,
  `corpus_regression_entries_test.dart`). `dart analyze` over
  `test/plugins/tdd`: **174 issues, every one naming a missing
  differential symbol** (`StepVector` ×20, `EntryVector` ×14,
  `compareEntryVectors` ×6, `CorpusDifferentialCommand` ×3, …).
  `dart test` on the five files: **`+0 -5: Some tests failed`** — all
  five failing at load, i.e. the capability did not exist.
- **GREEN (post-implementation):** the same files run **56/56**
  (12 model + 7 loader + 17 runner + 11 command + 9 content pins).
  Each command-level test drives the real compare/report/exit pipeline
  in-process with the git and subprocess layers faked (the
  `CorpusStepRunner` injectable-spawner pattern), asserting exit codes
  0/1/2, the summary line, the named divergence report, and
  scratch/worktree cleanup.

## e2e (REAL binary, REAL worktrees, REAL corpus)

All runs used `dart run bin/zfa.dart tdd corpus differential` from the
working tree (differential itself) driving committed-ref worktrees
(the generator under test), `--budget` as noted:

1. **Sanity — HEAD vs HEAD, each of the three entries:**
   `u2-flow` (104 s), `make-suite-baseline-flag` (290 s),
   `make-baseline-cache` (289 s) — all
   `[diff] <entry> -> match`, `result=match`, **exit 0**. The shipped
   corpus is deterministic, and a healthy pair passes.
2. **The #744 class — synthetic broken ref `b1ebfe28` vs HEAD
   (`--budget 45`):** the ref is HEAD plus a U2-conditional infinite
   stall in `gen_command.run()` (a pending-timer `Future.delayed`,
   committed in a throwaway detached worktree, never merged). Result:
   `[diff] u2-flow -> differ (complete, hang, failed vs complete,
   complete, failed)` with the named finding **`gen U2: hang vs
   complete`**, plus the count finding (`+0 -1` vs `+0 -2` — the
   broken ref never produced U2's test) and two `artifact-added`
   findings — **exit 1**, `result=differ`. This is the issue's
   done-when shape ("fails differential with … hang vs complete"),
   realized with a deterministic broken ref because a plain revert of
   #748 does not hang on a healthy project (the recorded #744 trigger
   was machine-specific; #748's own deadlock-inspection test pins that).
3. **The #751 replay — `2e3f09e4` (=`14651299^`, the last commit whose
   `make_command.dart` has zero `suite-baseline` occurrences — verified
   with `git show | grep -c`) vs HEAD (`--budget 150`):**
   `[diff] make-suite-baseline-flag -> differ` with **`make U1: failed
   vs complete`** (the old make aborts with "Could not find an option
   named '--suite-baseline'" — the exact #751 report), `gen U1: token
   (none) vs created` (pre-#840 verdict absence), and the
   non-namespaced→namespaced artifact findings (pre-#827) — **exit 1**.
   One command would have caught #751 before merge.
4. **Budget honesty note (recorded, then corrected):** a first Demo-B
   run with `--budget 60` recorded HEAD's make as `hang` — a real
   observation under that budget (JIT-cold `dart test` inside make),
   not a misclassification; re-run at the default-class 150 s budget
   completed. The 45–60 s budgets also surfaced that a bare
   `await Completer().future` stall does NOT hang the Dart VM — an
   empty event loop drains and the child exits 0 silently (first
   Demo-A attempt recorded `token (none) vs created` with exit 0 and
   no generated files) — so the synthetic stall uses a pending timer
   (`Future.delayed`), after which the child really dies by SIGKILL at
   the budget (probed directly: exit 137 at 25 s) and `runTimed`'s
   `ProcessTimeoutException` maps to the `hang` vector as designed.

## Findings

- `ProcessResult`'s positional order is `(pid, exitCode, …)` — the
  first fake-spawner helpers had it swapped and every outcome read as
  `failed`; the fast tier caught it before any real spawn. Worth
  remembering for every future spawn-faking suite.
- Frozen post-gen scaffolds are NOT portable across project roots: the
  artifact registry stores absolute paths and `preflight` refuses
  cross-root mismatches. The corpus entries therefore rebuild state
  through the generator inside the scratch (gen → verify-red → make),
  which also makes each entry replay its incident's real command
  sequence. A registry-side relative-path mode is a separate, future
  concern (#805 does not touch `artifact_registry.dart`).
- `dart pub get` at this repo's root resolves `example/` and needs the
  Flutter SDK; the differential's setup steps use
  `dart pub get --no-example` so the gate runs on a Dart-only CI image.

## Mutation results (deliberate mutants — no mutation tool in profile)

All applied to the working tree, tested, then restored byte-identical
(diff-verified against pre-mutant copies):

- **M1** — `compareEntryVectors`: outcome-divergence findings removed
  (dead-code guard on the `a.outcome != b.outcome` branch) → CAUGHT
  (`+11 -1` in the model file: the outcome-divergence test).
- **M2** — `DifferentialRefRunner._runStep`: `hang` mapped to `failed`
  → CAUGHT (`+27 -1`: "a deadline hit is the hang outcome (the #744
  class), exit -1"); with the mutant the command-level run also
  printed `differing=0 … result=match` — the exact false-negative the
  gate must never produce.
- **M3** — `DifferentialCorpus.load`: empty-corpus refusal disabled →
  CAUGHT ("a corpus dir with zero entries is the empty failure").
- **M4** — command: `exitCode = _exitMatch` unconditionally → CAUGHT
  (both exit-code tests fail: `hang-vs-complete … exit 1`,
  `artifact-inventory divergence is a differ verdict`).

**Score 4/4.**

## Traceability (issue slice v0 → tests)

| #805 slice | Evidence |
| --- | --- |
| Corpus runner against two refs | runner tests 17 (resolve/worktree/setup/runEntry classes) + e2e 1–3 |
| Result-vector compare (exit codes, pass/fail counts, artifact inventory) | model tests 12 (outcome classes, deep equality, step/count/artifact findings) + Demo-A counts/artifact findings |
| One regression entry per incident (744/751/752) | content pins 9 (names, incidents, the #744 two-gen shape, `--suite-baseline` in both make entries, scaffolds complete) + e2e 2–3 |
| GitHub Actions gate on generator-touching PRs, <20 min | workflow pins 4 (invocation, `timeout-minutes: 20`, `fetch-depth: 0`, PR trigger) + measured per-entry e2e wall times (104–290 s) |
| Machine contract | command tests (summary line, exit 0/1/2, `[diff]` report), house `differential:` line on every exit path |
| Hang honesty (#744 class) | runner hang tests + M2 + e2e Demo A |

## What was not audited

- #792 batch scheduling is not integrated: entries run sequentially per
  ref; throughput work is a separate slice.
- The GitHub Actions workflow was not executed on real runners; its
  pins are content-level. The 20-minute budget is supported by the
  measured per-entry e2e times (104–290 s per entry per ref pair,
  including one JIT-compile-heavy generator spawn per step), not by a
  real Actions run.
- Artifact comparison is inventory-only (paths), by design; content
  drift within an existing artifact is invisible to the gate.
- Windows worktree semantics (paths, SIGKILL) were not exercised; the
  gate targets the Linux CI image.
- `spec 051`'s corpus run/status/audit flows are untouched; the
  differential is additive to the `corpus` family (one registration
  line in `corpus_command.dart`).

## Shared verify (branch-level)

```
dart analyze lib test
# 1 issue: pre-existing unused import in test/commands/entity_help_test.dart
# (file untouched by this branch). Zero new.

tools/run_tests_chunked.sh (official chunk list, 67 test chunks,
foreground, kernel caches cleared between chunks):
  62 PASS / 5 SKIP (empty chunks) / 0 FAIL
test/plugins/tdd re-run (covers root-level files the chunker does not
split, incl. corpus_regression_entries_test.dart): 549 tests, all passed.

dart format --set-exit-if-changed --output=none lib/src/plugins/tdd test/plugins/tdd
# 0 changed. git diff after format: the fix, its tests, corpus/, and the
# workflow only — no format drift, pubspec.lock restored to HEAD.
```
