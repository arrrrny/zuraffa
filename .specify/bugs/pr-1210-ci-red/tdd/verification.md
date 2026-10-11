# TDD Verification: pr-1210-ci-red

- **Audited**: 2026-09-06
- **Mode**: LLM-guided fallback audit (zfa tdd verify cannot address
  `.specify/bugs/` dirs — engine resolves features only under `specs/`;
  `.zfa.json` absent). Rubric per `.specify/memory/tdd-profile.md`.
- **Gate verdict**: **PASS**

## 1. Test-first evidence

The pre-fix (red) version of `test/regression/issue_891_example_meta_resolution_test.dart`
was committed at HEAD `350e2d8e` (shipped by #1206's branch); the rewrite
exists only as the fix-branch working-tree change. The loop re-proved RED
against the committed file BEFORE rewriting — order preserved. Evidence:
`tdd/cycle-log.md` Cycle 1 RED block (3 failures, byte-equivalent to master CI
run 34027280435's failures).

## 2. Red-phase evidence

RED for the right reason: old tests 1–3 assert the override #1206 removed
(`Expected: <Instance of 'Map'> Actual: <null>` / Null-cast errors). Matches
the CI symptom that filed issue #1211. Not a trivially-red test (no thrown
ToBeImplemented stub) — it red exactly on the contract flip.

## 3. Test smells

- Deterministic: pure file reads + YAML parse; no sleeps, randomness, network,
  or subprocesses. Passes in ~2s.
- Names are observable-result sentences (profile convention).
- Reason strings carry the contract history and remediation path (what to do
  before flipping the guard back).
- A3's `contains('example')` substring assertion is an intentional pointer
  guard on the delegation target; the in-test reason documents the update
  path if the gate moves. Accepted, not a smell in the regression-guard genre.

## 4. Mutation sampling (deliberate mutants; no mutation tool wired)

| Mutant | Target behavior | Result |
|---|---|---|
| Re-append `dependency_overrides: {meta: ^1.18.3}` to example/pubspec.yaml | A2 | **killed** — `+0 -1: ...ZERO dependency_overrides... [E]` |
| Remove tools/flutter_smoke_gate.sh (mv aside) | A3 | **killed** — `+0 -1: ...delegated to tools/flutter_smoke_gate.sh [E]` |

Both runs restored afterwards; post-restore full-file run: `+3: All tests passed!`

## 5. Acceptance-criteria coverage

| AC | Covered by |
|---|---|
| AC-1 suite green on zero-overrides tree | A1+A2+A3 all green |
| AC-2 override must NOT exist | A2 (mutant-killed) |
| AC-3 test 4 no longer keys on analyzer floor; smoke gate delegated | A3 (mutant-killed) |
| AC-4 history preserved in doc comment | satisfied in rewrite (review-level, per test-list) |
| AC-5 path-override prohibition | subsumed by A2 (no section → nothing overridable) |

## 6. Out-of-scope finding (not a gate input)

`test/regression/issue_1059_entity_cli_bare_exit_code_test.dart` (4 tests,
6 total failures in the full folder run) times out locally — `zfa subprocess
exceeded its 75s child timeout`. Stash-bisect on pristine HEAD `350e2d8e`
reproduces the failure WITHOUT the fix → pre-existing local-environment flake
(cold `dart bin/zfa.dart` start under load), not a regression. CI passes these
tests on the same commit.
