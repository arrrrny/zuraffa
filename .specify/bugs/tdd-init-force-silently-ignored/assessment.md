# Bug Assessment: zfa tdd init --force is silently ignored; should overwrite existing files

- **Slug**: tdd-init-force-silently-ignored
- **Created**: 2026-09-01
- **Source**: https://github.com/arrrrny/zuraffa/issues/666
- **Verdict**: valid
- **Severity**: low

## Report (verbatim or summarized)

Running `zfa tdd init` in a project that already has a `.specify/memory/tdd-profile.md` with different content (e.g., a project re-classified as Flutter vs Dart, or a hand-edited profile) throws a `StateError` and exits non-zero — even when `--force` is passed. The `--force` flag is silently ignored: accepted by the argument parser as an unknown extra and discarded, so `TddProfileWriter.write()` always hits its "refusing to overwrite" guard and throws.

## Symptom

`zfa tdd init --force` does not overwrite an existing `tdd-profile.md`; instead it throws `Bad state: tdd-profile.md already exists at ... with different content; refusing to overwrite.`

## Reproduction

1. Run `zfa tdd init` in a project that already has a `.specify/memory/tdd-profile.md` with different content.
2. Run `zfa tdd init --force`.
3. Observe the `StateError` and non-zero exit.

## Suspected Code Paths

- `lib/src/cli/commands/init_command.dart` — `InitCommand` never registers the `--force` flag, so it is silently absorbed as an unknown argument.
- `lib/src/cli/writers/tdd/tdd_profile_writer.dart` — `TddProfileWriter.write()` has no `force` parameter; it always throws `StateError` when an existing file's content differs from what it would generate.

## Root Cause Hypothesis

Two mechanical gaps: (1) `InitCommand.argParser` does not register `--force`/`-f`; (2) `TddProfileWriter.write()` has no `force: bool` parameter, so even a registered flag could not reach the writer. Confidence: **high** — the flag is unregistered and the writer has no force path.

## Proposed Remediation

**Preferred**:
1. Register `--force` (`-f`) in `InitCommand.argParser`.
2. Pass a `force: bool` flag down through `TddProfileWriter.write()` (and the other baseline writers).
3. When `force == true` and the file exists with different content, delete and re-create it instead of throwing.

**Files likely to change**:
- `lib/src/cli/commands/init_command.dart`
- `lib/src/cli/writers/tdd/tdd_profile_writer.dart`
- (possibly) other baseline writers that share the overwrite guard

**Tests to add or update**:
- `zfa tdd init --force` overwrites an existing `tdd-profile.md` with different content and exits 0
- `zfa tdd init` (no `--force`) still refuses to overwrite (no regression)
- `--force`/`-f` both accepted

## Risks & Considerations

- `--force` must not silently overwrite unrelated files; scope it to the baseline writers.
- Ensure the re-created file content is byte-identical to a fresh generation.

## Open Questions

- None blocking.