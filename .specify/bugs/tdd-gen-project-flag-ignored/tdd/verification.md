# TDD Verification: tdd-gen-project-flag-ignored (GitHub issue #1272)

- **Slug**: tdd-gen-project-flag-ignored
- **Tested**: 2026-09-07 (UTC+8), session ran on branch `fix/1272-tdd-gen-project-flag-ignored` (base master `d3679e0f`)
- **Assessment**: ../assessment.md
- **Fix**: `lib/src/plugins/tdd/commands/gen_command.dart` (single guard site: `GenCommand.testListScopeRejection` consulted in `GenCommand.run` BEFORE any test-list resolution; artifact-path validation unchanged)
- **Tests**: `test/plugins/tdd/bug_1272_gen_project_scoped_test_list_test.dart` (5 unit + 7 CLI)
- **Verdict**: **PASS**

## Gate Summary

| Gate | Result |
|------|--------|
| Red-phase evidence (bug pinned before fix) | pass |
| Green-phase (bug suite passes post-fix) | pass (12/12) |
| Mutation strength (changed-file mutants) | 2/2 killed, 0 survived |
| Regression (gen-related suites) | no new failures |
| Analyzer / formatter gates | clean |

## Red-Phase Evidence (master d3679e0f, before the fix)

`dart test --preset=all test/plugins/tdd/bug_1272_gen_project_scoped_test_list_test.dart`
→ `+4 -2: Some tests failed` — failing for the RIGHT reason: gen read the
foreign 7-column `example/specs/004-login-ui/tdd/test-list.md` and surfaced
its parse error as its own (the issue's byte-for-byte repro):

```
❌ Error: Bad state: zfa tdd gen: malformed test list — test-list.md line 7:
expected 4 columns (id/behavior/traces/state), found 7: "| A1 | acceptance |
US1, S1 | DONE | toggle method is generated across all layers |
test/integration/toggle_method_test.dart | zzz |"
```

(The batch variant additionally masked the cause as `verdict=stopped`.)

## Green-Phase Evidence (post-fix)

`dart test --preset=all test/plugins/tdd/bug_1272_gen_project_scoped_test_list_test.dart`
→ `+12: All tests passed!`

- containment: a `--feature` whose resolution normalizes outside
  `<project>/specs` is rejected BEFORE any read (`outside the project root` message),
  even when the escape target is a VALID foreign list
- segment shape: path-shaped refs inside the root (`specs/001-login-ui`)
  are usage-rejected (`invalid --feature`)
- strict `--project` scoping over the decoy-laden monorepo still resolves
  the PROJECT row; the unscoped (no `--feature`) scan reads ONLY the
  project specs tree; default (no `--project`) resolution unchanged

## Mutation Evidence (on the changed resolution logic)

| Mutant | Change | Result | Killed by |
|--------|--------|--------|-----------|
| A | containment rejection disabled (`if (false)`) | KILLED — 6 failures | unit containment tests ×2, dot-segment test, CLI escape tests ×3 |
| B | segment-shape rejection disabled (`if (false)`) | KILLED — 3 failures | unit segment-shape test, dot-segment test, CLI inside-root test |

## Regression (only gen-touching suites — cloud-agent scoping)

| Suite | Result |
|-------|--------|
| bug_890_gen_project_autodetect_test + tdd_command_smoke_test + corpus_economics/batch_gen_test + json_flag_test | 43/43 pass |
| scenarios/sc_019 + bug_969_proof_receipts + bug_830_widget_subject_kind + bug_840_recovery | 31 pass, 5 fail — **pre-existing on pristine master d3679e0f** (bug_840 reset/adopt JSON-envelope drift; reproduced with the fix stashed, unrelated to this change) |
| services/step_runner_test (driver spawns gen) | 18/18 pass |

## Tooling Gates

- `dart analyze lib/src/plugins/tdd/commands/gen_command.dart test/plugins/tdd/bug_1272_gen_project_scoped_test_list_test.dart` → `No issues found!`
- `dart format .` executed; the working tree carries only the fix + the new test (both formatter-clean). NOTE: 3 pre-existing evidence files under `specs/1142-adaptive-layout-contract/tdd/evidence/` are unformatted on master — left untouched (out of scope, one PR per bug).
- Kernel-cache hygiene: `.dart_tool/test/` + `dart_test.kernel.*` cleaned pre/post test runs.

## Honest Gaps

- Full-suite mutation testing (`zfa tdd verify`'s deterministic harness) not
  run: the repo root is not zfa-wired (no `.zfa.json`), so the LLM-guided
  fallback audit applied. Mutation coverage was executed directly on the
  changed resolution logic instead (2/2 killed above).
- The symlinked-feature-dir edge (a symlink INSIDE `specs/` pointing
  outside the root) is out of scope for this fix — the issue's escape is a
  path-walk (`..`) through the `--feature` reference, which is now blocked
  at both tiers.
