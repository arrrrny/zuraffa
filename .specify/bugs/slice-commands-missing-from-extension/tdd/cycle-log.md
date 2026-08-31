# Cycle Log: slice-commands-missing-from-extension (bug 598)

Append-only. One entry per cycle. All evidence below is from real runs in the
session that produced the branch `fix/598-slice-commands-missing-from-extension`.

## Baseline

- Date: 2026-08-31 — HEAD: `11de4bf` — suite baseline: green
- `dart test --preset=all test/cli/standard/extension_command_parity_test.dart -p vm`
  → `00:00 +2: All tests passed!` (registry coverage + doc shape; the file
  carried 2 tests at baseline)
- The bug's original failure signature (3 missing `provides:` entries) is NOT
  reproducible at this commit: PR #600 (`222785f`) already added the three
  `provides:` entries and the three `commands/slice/*.md` files on master.
  The remaining, verifiable gap at `11de4bf` is that the four slice
  `provides:` entries reference `category: slice` while `categories:` does not
  declare it.

## Cycle 1 — U1: categories map declares the slice category

- RED (yml fix temporarily stashed to reproduce the pre-fix state):
  - Command: `dart test --preset=all test/cli/standard/extension_command_parity_test.dart -p vm --plain-name 'extension categories map declares the slice category'`
  - Output:
    ```
    00:00 +0 -1: extension categories map declares the slice category [E]
      Expected: contains 'slice'
         Which: does not contain 'slice'
      slice provides entries reference category: slice, which must be declared under categories:
    00:00 +0 -1: Some tests failed.
    ```
- GREEN (fix restored — `categories: slice` declared in extension.yml):
  - Command: `dart test --preset=all test/cli/standard/extension_command_parity_test.dart -p vm`
  - Output: `00:00 +3: (tearDownAll)` → `00:00 +3: All tests passed!`
    (registry coverage + categories guard + doc shape)
- Refactor: none required (test models the file's existing parse-and-expect style).

## Test strength sampling (deliberate mutants, post-green)

No mutation tool is wired for this repo (tdd-profile), so deliberate mutants were
sampled on the registration surface. Each mutant was restored exactly and the
suite re-run green before the next step.

| Mutant                                                                   | Expected guard | Result                                                  |
| ------------------------------------------------------------------------ | -------------- | ------------------------------------------------------- |
| Remove `aliases: [zfa.slice.merge_slice]` from `extension.yml`            | registry coverage test | CAUGHT — `Actual: ['slice/merge_slice -> zfa.slice.merge_slice']` (the exact issue #598 signature) |
| Delete `commands/slice/verify_slice.md`                                   | registry coverage + doc shape | CAUGHT — `Actual: ['zfa.slice.verify_slice -> commands/slice/verify_slice.md (file missing)']` and `(missing)` |
