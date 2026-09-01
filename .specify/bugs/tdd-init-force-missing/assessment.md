# Bug Assessment: zfa tdd init silently ignores --force flag

- **Slug**: tdd-init-force-missing
- **Created**: 2026-09-01
- **Source**: pasted text
- **Verdict**: valid
- **Severity**: low

## Report (verbatim or summarized)

> it should simply allow --force and clearly tells user so when zfa tdd init --force is called it overwrites
>
> ```
> $ cd /Users/ahmettok/Developer/zuraffa_permissions && zfa tdd init 2>&1
> zfa tdd init: ensuring TDD baseline in /Users/ahmettok/Developer/zuraffa_permissions (Dart)
>    ✗ .specify/memory/tdd-profile.md: Bad state: tdd-profile.md already exists at
> /Users/ahmettok/Developer/zuraffa_permissions/.specify/memory/tdd-profile.md with
> different content; refusing to overwrite. Delete the file first if you want to regenerate.
> … (9 more lines, ctrl+o to expand)
> ```

## Symptom

Running `zfa tdd init` in a project that already has a `.specify/memory/tdd-profile.md` with different content (e.g., a Dart project that was previously initialized as Flutter or vice versa) throws `StateError: Bad state` and exits with a failure, even when `--force` is passed. The `--force` flag is silently ignored — it is accepted by the argument parser but has no effect — and the user is told to "delete the file first" rather than having `--force` handle it.

## Reproduction

1. Run `zfa tdd init` in a project (creates `.specify/memory/tdd-profile.md`).
2. Modify the file's content (e.g., change `runner: flutter_test` to `runner: flutter_test` in a Flutter project, or manually edit it).
3. Run `zfa tdd init --force`.
4. Observe: `Bad state: tdd-profile.md already exists at … with different content; refusing to overwrite. Delete the file first if you want to regenerate.`

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/init_command.dart:17–26` — `InitCommand` does not register a `--force` flag; it is silently accepted as an unknown extra and discarded.
- `lib/src/cli/writers/tdd/tdd_profile_writer.dart:23–33` (`write`) — the only branch is `file.exists()` → compare content → throw `StateError` if different. No `force` parameter exists to bypass this.
- `lib/src/plugins/tdd/commands/init_command.dart:59–71` — catches `StateError` and reports it as a failure. No `force` path is passed through.

## Root Cause Hypothesis

Confidence: **high**.

The `--force` flag is never registered in `InitCommand`'s arg parser (line 17–26), so it is silently absorbed as an unknown argument. When the existing `tdd-profile.md` has different content than what `TddProfileWriter` would generate (e.g., the project was re-classified as Flutter vs. Dart, or the profile was hand-edited), `TddProfileWriter.write()` throws `StateError` refusing to overwrite, and the init command surfaces this as a failure.

The `--force` flag was presumably intended to bypass the "refusing to overwrite" check, but it was never wired through: `InitCommand` doesn't register it, `TddProfileWriter.write()` doesn't accept it, and no other writer in the init chain has a force option either.

## Proposed Remediation

**Preferred**: Wire `--force` through the full init chain:

1. Register `--force` (`-f`) in `InitCommand.argParser`.
2. Pass a `force: bool` flag down to `TddProfileWriter.write()` (and every other writer called by `InitCommand`). When `force == true` and the file exists with different content, delete and re-create it instead of throwing.
3. In `InitCommand`, read the `--force` flag and pass it to each writer.

For the `TddProfileWriter.write()` case specifically: when `force == true`, skip the content comparison and overwrite unconditionally (after backing up or simply replacing — no backup needed since git history is the backup).

**Alternative**: Make `--force` imply "delete all generated baseline files first, then recreate them". Simpler to implement but a bigger hammer — it re-creates files even when their content matches, which is wasteful.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/init_command.dart` — add `--force` flag and pass it to writers.
- `lib/src/cli/writers/tdd/tdd_profile_writer.dart` — accept and honor a `force` parameter.
- `lib/src/cli/writers/tdd/dart_test_yaml_writer.dart` — check if it has a similar "refusing to overwrite" guard and extend it with `force` too.
- `lib/src/cli/writers/tdd/smoke_test_writer.dart` — same as above.
- `lib/src/cli/writers/tdd/app_module_writer.dart` — same as above.
- `lib/src/cli/writers/tdd/pubspec_dev_dependencies_patcher.dart` — same as above (though this may already be idempotent).

**Tests to add or update**:
- `test/plugins/tdd/tdd_command_smoke_test.dart` or a new `init_command_test.dart` — test that `zfa tdd init --force` overwrites a file with different content and exits 0.
- `test/cli/writers/tdd/tdd_profile_writer_test.dart` — add a test for `write(force: true)` overwriting an existing file with different content.

## Risks & Considerations

- **Data loss**: `--force` overwrites existing files. This is intentional (the user's explicit opt-in), but the error message currently says "delete the file first" — the fix should make the success path equally clear: `--force` overwrites.
- **API breakage**: None — `--force` is new flag behavior; no existing contracts change.
- **Idempotency**: `zfa tdd init` without `--force` should remain idempotent for matching content (currently works correctly).
- **Other writers**: Need to audit whether `DartTestYamlWriter`, `SmokeTestWriter`, and `AppModuleWriter` have similar "refusing to overwrite" guards. The bug report only mentions `tdd-profile.md` but the same pattern could appear in other writers.

## Open Questions

- [NEEDS CLARIFICATION: Does the user expect `--force` to overwrite only `tdd-profile.md`, or all baseline files? The simpler per-file approach is recommended, but a global "wipe and recreate" alternative may be more intuitive.]
- [NEEDS CLARIFICATION: Should the fix also apply to the other writers (`DartTestYamlWriter`, `SmokeTestWriter`, `AppModuleWriter`) if they have similar guards, or is `tdd-profile.md` the only affected file?]
