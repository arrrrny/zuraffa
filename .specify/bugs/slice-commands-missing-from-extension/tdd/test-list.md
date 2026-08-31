# Test List: slice merge/verify/export not registered in speckit zuraffa extension (bug 598)

---
feature: slice-commands-missing-from-extension # bug dir (spec-kit feature resolver errors for bug work; resolved per the bug extension's per-bug layout)
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 3 # AC1 registry coverage, AC2 doc shape, AC3 0 missing (as traced by test/cli/standard/extension_command_parity_test.dart and the assessment's expectations)
planned_at: 11de4bf
updated_at: 11de4bf
suite_baseline: green
---

Scope note: the branch's change is the `categories: slice` declaration in
`.specify/extensions/zuraffa/extension.yml` plus the guard test for it. The
registration entries and `.md` files for `merge_slice` / `verify_slice` /
`export_slice` were already remediated on master by PR #600 (`222785f`) before
this branch was cut, so their behavior is baselined, not re-developed here.

## Outer loop: acceptance behaviors

| id  | behavior                                                                                                             | traces                                          | kind            | state        | test                                                                                                         |
| --- | -------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------- | --------------- | ------------ | ------------------------------------------------------------------------------------------------------------ |
| A1  | Every `zfa manifest` command is registered in the speckit extension `provides:` and its `.md` exists and is template-shaped (AC1 registry coverage, AC2 doc shape, AC3 0 missing) | AC1, AC2, AC3 | characterization | BASELINE | `test/cli/standard/extension_command_parity_test.dart::every zfa manifest command is registered in the speckit extension` + `::each command .md follows the template shape` |

## Inner loop: unit behaviors

### `.specify/extensions/zuraffa/extension.yml`

| id  | behavior                                                                            | traces                                                              | kind    | state | test                                                                                  |
| --- | ------------------------------------------------------------------------------------ | -------------------------------------------------------------------- | ------- | ----- | -------------------------------------------------------------------------------------- |
| U1  | The extension `categories:` map declares `slice`, the category the slice `provides:` entries reference | Issue #598 hard constraint; assessment "Risks & Considerations"     | example | DONE  | `test/cli/standard/extension_command_parity_test.dart::extension categories map declares the slice category` |
