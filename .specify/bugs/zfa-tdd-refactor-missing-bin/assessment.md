# Bug Assessment: [BUG] zfa tdd refactor: calls dart run bin/zfa.dart build which does not exist

- **Slug**: zfa-tdd-refactor-missing-bin
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/689
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

`zfa tdd refactor` hardcodes `dart run bin/zfa.dart build` as the first pass in the fixed registry, but `zfa setup` does not create `bin/zfa.dart` in the project directory — it only installs the system-level `~/.local/bin/zfa` CLI. The result is exit 255 (`dart: Could not resolve the package: Missing bin/zfa.dart in the package.`) on any project bootstrapped with `zfa setup`. Reported by arrrrny with full reproduction steps.

## Symptom

When `zfa tdd refactor` runs in a freshly bootstrapped project, the `build` pass fails immediately with exit code 255 and the error `dart: Could not resolve the package: Missing bin/zfa.dart in the package.` — because `bin/zfa.dart` does not exist.

## Reproduction

1. `zfa setup --platforms=ios,android,macos zik_zak_tdd`
2. `cd zik_zak_tdd && zfa tdd init`
3. Copy any spec (e.g. `specs/001-app-bootstrap/spec.md`)
4. `zfa tdd plan 001-app-bootstrap`
5. `zfa tdd gen A7 --feature=001-app-bootstrap`
6. `zfa tdd make --feature=001-app-bootstrap A7`
7. `zfa tdd refactor --feature=001-app-bootstrap A7`
   → **exit 255**: `dart: Could not resolve the package: Missing bin/zfa.dart in the package.`

## Suspected Code Paths

- `lib/src/plugins/tdd/services/refactor_passes.dart:181` — the hardcoded `build` pass command: `'dart run bin/zfa.dart build'`. This is the direct source of the failure.
- `lib/src/plugins/tdd/services/refactor_passes.dart:175-184` — the `defaultPassSpecs` constant comment (line 177) says the local CLI is intentional "so it does not depend on a globally activated `zfa` executable being on `PATH`" — this rationale is now wrong since `zfa setup` installs `zfa` globally.
- `lib/src/plugins/tdd/commands/refactor_command.dart:13` — doc comment references the same hardcoded command.
- `lib/src/plugins/tdd/commands/refactor_command.dart:78` — description string references the same hardcoded command.
- `test/plugins/tdd/services/refactor_passes_test.dart:128` — test asserts the hardcoded command; will need updating.

## Root Cause Hypothesis

**High confidence.** `RefactorPasses.defaultPassSpecs` (refactor_passes.dart:181) pins `'dart run bin/zfa.dart build'` as the build pass. This command requires `bin/zfa.dart` to exist in the project's root, but `zfa setup` only runs `flutter create`/`dart create` and installs the system `~/.local/bin/zfa` — it never scaffolds a local `bin/zfa.dart`. The `build` pass always fails on first execution in any new project, making the entire refactor step unusable.

## Proposed Remediation

**Preferred**: Change the hardcoded build pass command in `refactor_passes.dart` from `'dart run bin/zfa.dart build'` to `'zfa build'`. This delegates to the system-installed `zfa` (which `zfa setup` already places on `PATH`), eliminates the dependency on the non-existent project-local `bin/zfa.dart`, and aligns with the comment's stated intent (using a globally activated executable) while fixing the comment's now-obsolete rationale.

**Alternatives**:
- Have `zfa setup` scaffold a minimal `bin/zfa.dart` stub that forwards to the system `zfa` binary. More work, creates a file that must be kept in sync, and is redundant given the global installation.
- Accept a `--zfa-bin` flag in `RefactorPasses` to allow overriding the command. Adds complexity and a flag users must know to set; does not fix the out-of-the-box failure.

**Files likely to change**:
- `lib/src/plugins/tdd/services/refactor_passes.dart` — change `defaultPassSpecs` command string and update the doc comment on line 177.
- `lib/src/plugins/tdd/commands/refactor_command.dart` — update doc comment (line 13) and `description` getter (line 78) to reflect the new command.
- `test/plugins/tdd/services/refactor_passes_test.dart:128` — update the expected command string in the existing assertion.

**Tests to add or update**:
- The existing `refactor_passes_test.dart` test at line 128 that asserts `build.command == 'dart run bin/zfa.dart build'` must be updated to assert `'zfa build'`.
- A regression test verifying that `RefactorPasses` with the default spec runs successfully when `bin/zfa.dart` is absent (using a fake executor that verifies `zfa build` was invoked).

## Risks & Considerations

- Any user who has a project-level `bin/zfa.dart` (e.g. from manual setup or older zuraffa versions) will switch from the local to the system binary. Behavior should be identical since both invoke the same `build` subcommand.
- The fix assumes `zfa` is on `PATH` (true for every user after `zfa setup`).
- The `refactor_passes_test.dart` test at line 128 will fail without the corresponding update — this is a required co-change.

## Open Questions

- [RESOLVED: Which file hardcodes `dart run bin/zfa.dart build`?] `refactor_passes.dart:181`
- [RESOLVED: Should the fix switch to system `zfa build` or scaffold `bin/zfa.dart`?] System `zfa build` is simpler and aligns with the existing install mechanism.
- [NEEDS CLARIFICATION: Are there any environments where `zfa setup` does not put `zfa` on `PATH`?] If so, an explicit `PATH`-discovery fallback might be needed, but this is likely not the common case.
