# Bug Verification: 1480 — zuraffa spec authoring grammar never reaches a spec-kit project

- **Slug**: 1480-spec-grammar-propagation
- **Tested**: 2026-09-11T00:42:00Z
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified
- **TDD verification**: ./tdd/verification.md (verdict PASS_WITH_GAPS — gaps are environmental: no mutation run, chunked regression)

## Summary

The bug no longer reproduces: a spec-kit-shaped spec with untraced FRs is refused at plan time in seconds (exit 1, no artifacts, spec untouched) instead of dead-ending 28 minutes into `zfa tdd run`; the same spec resolves its unit lane declared once the mapping is declared in `contracts/*.md`; `zfa tdd init` installs the zuraffa-1.0 authoring grammar into a fresh project. No regressions found in the affected suites.

## Checks Performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Reproduction (post-fix) | `dart run bin/zfa.dart tdd plan 001-todo-app --project <fresh spec-kit-shaped project>` (issue's repro shape) | pass | exit **1**, class `unit-fallback-refused`, names `U1 (FR-001)`, no test-list written, spec byte-identical — the issue's Actual (exit 0 into a 27m41s dead-end) is unreachable |
| Decoupled mapping | same project + `contracts/todo-seam.md` (row + `**FR-001**: traces: TodoStore.add`), re-plan | pass | exit **0**, `route: U1 -> unit lane (func surface) [declared: contract row: TodoStore, spec line 6]` — the issue's Expected ("mapping held somewhere other than spec.md") |
| Template propagation | `dart run bin/zfa.dart tdd init --project <fresh project>`, then grep the installed template | pass | `## Layer Contracts`=1, `traces:`=4, `**Template Version**: zuraffa-1.0` present; idempotent re-init reports already-current and exits 0 — the issue's Expected ("grammar template installed when zfa wires it up") |
| New/updated tests | `dart test` on the three new files | pass | 14/14 (red→green evidence in tdd/cycle-log.md) |
| Regression suite (changed paths) | `dart test test/plugins/tdd/services/ -j 2` → 804/804; chunked re-runs of `test/plugins/tdd/commands/` (64 files) + plan-adjacent root files + `test/cli/writers/tdd/` | pass | legacy fixtures updated to the #1480 contract or the escape hatch where the fallback is the subject; details in fix.md |
| Analyzer / formatter | `dart analyze <changed files>`; `dart format` | pass | No issues found; 0 remaining formatting diffs on changed files (2 pre-existing unformatted files on master reverted out of scope) |

## Output Excerpts

Fail-fast (real run):

```
zfa tdd plan: unit-fallback-refused — 1 unit behavior(s) would route through the legacy classifier fallback (spec: .../specs/001-todo-app/spec.md).
  route: U1 -> unit lane [fallback: FR-001 carries no declared contract trace]
  --> fix: add `traces: <Row>` under each FR above in spec.md, or declare the rows and the FR mapping in .../contracts/*.md ...
```

Declared via contracts file (real run):

```
route: U1 -> unit lane (func surface) [declared: contract row: TodoStore, spec line 6]
zfa tdd plan: wrote File: '.../tdd/test-list.md' with 1 acceptance + 1 unit behaviors (2 total).
```

Init (real run):

```
   ✓ .specify/templates/spec-template.md (created: the zuraffa-1.0 authoring grammar)
```

## Residual Risks

- Mutation testing not run (environment not zuraffa-wired); strong negative assertions mitigate but do not replace it.
- `zfa tdd plan`'s default contract changed: legacy specs with untraced FRs exit 1. The refusal names the three outs and `--allow-unit-fallback` preserves the legacy behavior; consumers with pre-grammar specs will see the refusal once — by design.
- The acceptance lane's fallback → marker migration (issue #1186) still exits 0 by design; the companion issue #1466 stays open for it.

## Recommendation

Close the bug — verified end-to-end at plan level (the issue's dead-end is unreachable) and at wiring level (the grammar propagates). Companion issues #1417/#1466 remain open on their own merits.
