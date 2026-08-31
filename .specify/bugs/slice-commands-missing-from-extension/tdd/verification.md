---
feature: slice-commands-missing-from-extension (bug 598)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 11de4bf
behaviors: 2
proven: 1
likely: 0
test_after: 0
no_test: 0
baseline: 1
high_smells: 0
criteria_total: 3
criteria_covered: 3
mutation_score: 2/2 deliberate mutants caught # scope: slice registration surface (extension.yml alias + command .md); no mutation tool wired per tdd-profile
mutants_survived: 0
suite: 2,267 passed, 0 failed (chunked fast tier, 59 folders) ; parity file 3 passed / 0 failed
---

# TDD Verification: slice merge/verify/export extension registration (bug 598)

**Verdict: PASS_WITH_GAPS.** This branch's own change (declaring `category:
slice` in `categories:`, guarded by a new test) went through a recorded
red→green cycle and every criterion is covered end-to-end through the real
`zfa manifest` entry point. The gaps: the bug's original remediation (the three
`provides:` entries and three `.md` files) predates this branch — it landed on
master in PR #600 (`222785f`) before this work started, so no test-first
evidence for it exists or can be produced; and mutation strength was sampled
with deliberate mutants (no tool is wired), not measured.

## Context the verdict depends on

- The prescribed red (parity test failing with 3 missing `provides:` entries)
  was executed at `11de4bf` and **passed**: the registration gap the issue
  describes was already closed on master by PR #600. The issue remains open
  only because that PR did not reference it. The remaining, reproducible gap
  at that commit was the undeclared `slice` category — the hard constraint the
  assessment marked "it already is", which it was not.
- `check-prerequisites.sh --json --paths-only` errors for this work (bug-driven
  work has no `specs/<feature>` directory). FEATURE_DIR was resolved per the
  bug extension's per-bug layout: `.specify/bugs/slice-commands-missing-from-extension/`.

## Test-first evidence

| Behavior | Class          | Evidence                                                                                          |
| -------- | -------------- | -------------------------------------------------------------------------------------------------- |
| U1       | PROVEN         | Cycle 1 red recorded (`Expected: contains 'slice' / Which: does not contain 'slice'`), fix + test committed together per the profile's convention |
| A1       | NOT_APPLICABLE | Characterization baseline: the parity suite was green at `11de4bf` before this branch changed anything |

Existing tests were not weakened: the only test file touched is
`extension_command_parity_test.dart`, and the diff adds one test; no assertion
was removed, loosened, renamed out of a filter, skipped, or excluded.

## Findings

| # | Severity | Finding                                                                                                                                                                                                                             | Evidence                                             |
|---| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------- |
| 1 | MED      | Eight other `provides:` entries reference categories that `categories:` does not declare: `integration` (api.create-api-bridge, mcp.scaffold), `graphql` (gql.generate, graphql), `tooling` (gym), `benchmark` (benchmark.list/register/run). Out of bug 598's scope (slice only); the committed guard is scoped to the #598 constraint so this PR stays minimal | `.specify/extensions/zuraffa/extension.yml` (observed while running the general form of the category guard during cycle 1) |
| 2 | LOW      | The assessment's "category: slice must be declared in extension.yml categories: (it already is)" was incorrect at `11de4bf`; auditors relying on it would skip the gap this PR closes                                                                                                                  | `.specify/bugs/slice-commands-missing-from-extension/assessment.md:97` |

## Mutation results

No mutation tool per `tdd-profile.md`; deliberate mutants on the slice
registration surface (2 sampled — this is a sample, not a measurement):

| Mutant                                                        | Behavior | Survived | Judgment                                              |
| ------------------------------------------------------------- | -------- | -------- | ----------------------------------------------------- |
| Removed `aliases: [zfa.slice.merge_slice]` from extension.yml | A1       | No       | Caught by the registry-coverage test with the exact issue #598 signature |
| Deleted `commands/slice/verify_slice.md`                      | A1       | No       | Caught by both registry-coverage and doc-shape tests  |

Both mutants were restored byte-exact and the parity file re-run green
(`00:00 +3: All tests passed!`) before proceeding.

## Traceability

| Criterion                                                                                     | Tests                    | End to end |
| ---------------------------------------------------------------------------------------------- | ------------------------ | ---------- |
| AC1 — registry coverage (every manifest command in `provides:`)                                | parity test 1            | Yes — drives the real `bin/zfa.dart manifest` subprocess |
| AC2 — doc shape (frontmatter + Usage / When to Use / Required Parameters / Flags / Output)     | parity test 3            | Yes — reads the registered `.md` files from disk      |
| AC3 — 0 missing (no unregistered command, no entry pointing at a missing file)                 | parity tests 1 and 3     | Yes                                                   |

Untested criteria: none. Tests tracing to nothing: none. The new U1 guard
traces to the issue #598 constraint (assessment "Risks & Considerations") and
completes, rather than duplicates, AC1.

## What was not audited

- The slow tiers (`regression` / `integration` / `property` / `benchmark`) were
  not run: `dart_test.yaml` excludes them from the fast tier and the repo's own
  guidance forbids `--preset=all`'s heavy tiers on small cloud agents. Five
  folders whose entire suites are slow-tagged (`test/benchmark`,
  `test/core/dependencies`, `test/integration`, `test/plugins/tdd/scenarios`,
  `test/property`) therefore report `dart test` exit 79 "No tests ran" in the
  chunked run — by design, not failures.
- The chunked runner's loop loses the chunk list to the MCP stdio test's stdin
  (`test/plugins/mcp` chunk), so chunks after it never start inside one
  invocation; they were run to completion separately with stdin redirected.
  Pre-existing runner quirk, not graded here.
- Mutation strength beyond the 2 sampled mutants; coverage was not run
  (opt-in per the profile).
- The `zfa.generate-commands` regeneration path (assessment "Alternatives") was
  not evaluated for auto-empting future parity gaps.
