---
feature: tdd-doctor-cross-feature-adoption (bug #874)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: working tree @ 7a4d0b57 # the fix lands as this PR's commit on top
behaviors: 3 # the three "Required" points of the bug
proven: 3
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: unmeasured # no mutation_test toolchain in this environment; gap recorded
suite: 68/68 chunked fast-tier folders OK; bug suite 11/11 green (7 red pre-fix)
---

# TDD Verification: tdd doctor cross-feature adoption (bug #874)

**Verdict: PASS_WITH_GAPS.** All three required behaviors are implemented
and tested through the real CLI surface (`CliRunner` + temp project
fixtures, no mocks of the stores), and the red evidence for every behavior
was captured in the same session before the fix was written
(`tdd/cycle-log.md` R-1, `tdd/red-evidence.txt`: `+4 -7`, including the
literal trust-violation reproduction — gen `--adopt` returning
`"verdict":"adopted"` for a file owned by another feature). The verdict is
not `PASS` because the audit was not independent (the same session wrote
the fix and the tests) and the mutation measurement was not run (no
mutation_test toolchain available; recorded as the standing gap, matching
the #828/#840 precedent).

## Requirement 1 — cross-registry awareness (PROVEN)

Before declaring a legacy-layout file "unowned", doctor (and gen's
recovery path) now consult EVERY `specs/*/tdd/artifacts.json`. A path
another feature records is `foreign-owned`; the doctor prescribes
`migrate` (never `adopt`), and gen refuses to register it into a second
registry. Evidence: R-1 reds (adopt prescribed for 001's files; gen
`--adopt` verdict `adopted`) flip to the `foreign-owned` contract in G-1;
controls pin the #840 semantics — a genuinely unowned flat file still
prescribes adopt, the owning feature's own doctor run stays healthy, and a
prior record in the SAME feature still refuses with `refused` (not
`foreign-owned`).

## Requirement 2 — migration path for #827 (PROVEN, pre-existing surface)

`zfa tdd migrate-paths` already exists on master (registered in
`TddCommand`, implemented in `migrate_paths_command.dart`): registry-driven
moves to the namespaced layout, runnable-name rewrite, pair-atomic with
rollback, cycle-log path rewrite, ownership-preserving refusals. The fix's
prescriptions target exactly that surface: the doctor's `migrate` fix names
`zfa tdd migrate-paths <owner>` — the OWNING feature's registry is the one
that must move — and the bare form for multiple owners. No auto-upgrade was
added: the issue offers it as an alternative to the command, and a doctor
READ silently mutating another feature's registry would violate the
least-surprise rule.

## Requirement 3 — owner named in verdicts (PROVEN)

The doctor's JSON verdict carries `owned_by` (foreign path -> owning
feature) and every foreign-owned drift line reads `... (owned by
<feature>): <path>`. Gen's `foreign-owned` verdict reason names the owner
feature and the migrate fix. Evidence: the owned_by assertions in the
suite (absolute and relative registry forms).

## Regression evidence

- Chunked fast tier: all 68 folders OK (house runner semantics: one
  folder per invocation, fast tier, kernel cache cleared per chunk; run in
  4 range batches because a single invocation exceeds the sandbox tool
  limit).
- Neighboring slow suites (bug_840, bug_828, gen_namespacing_827): the
  failures they show are PRE-EXISTING on pristine master — proven by
  `git stash` + re-run before attributing anything to this fix. The #840
  adopt fixtures seed flat-layout pairs that post-#827 gen never looks at
  (3 failures); the #828 doctor tests call the `--feature` API the merged
  #840 doctor superseded textually (4 failures; both PRs documented the
  supersession at merge time); the #827 two-feature/same-behavior-id
  scenario fails on master itself (1 failure). This PR changes none of
  those outcomes (identical tallies pristine vs. fixed) and does not
  repair them — one PR per bug.
- `dart analyze`: 47 repo issues, all pre-existing infos; zero in the
  changed files. `dart format --set-exit-if-changed`: zero diffs in the
  changed files (pre-existing drift in `migrate_paths_command.dart`
  committed by #869 is left untouched).

## Remaining gaps

1. Mutation strength unmeasured (no mutation_test toolchain in this
   environment). The new logic is small and boundary-tested (single vs.
   multiple owners, relative vs. absolute recorded paths, precedence over
   adopt, registry-untouched and byte-untouched refusal assertions), but
   the score is unrecorded rather than high.
2. The pre-existing master failures listed above are out of this PR's
   scope; they deserve their own triage (the #827 one is a genuine
   regression on master's headline scenario).
3. The doctor's legacy-layout scan intentionally covers only the flat
   `test/tdd` + `lib/tdd` roots (non-recursive), matching gen's historical
   default layout; a project that hand-placed artifacts elsewhere was
   never diagnosable and remains so.
