# Bug Assessment: `zfa tdd run` prints deprecation warning for 6-column lists but should handle them transparently

- **Slug**: `tdd-run-deprecation-warning-6-col`
- **Created**: 2026-08-31
- **Source**: pasted text (user-reported)
- **Verdict**: valid
- **Severity**: medium

## Report (verbatim)

```
~/D/forklift ❯❯❯ zfa tdd run 003-user-communication-interface
zfa: /Users/ahmettok/Developer/forklift/specs/003-user-communication-interface/tdd/test-list.md: deprecated 6-column test-list rows detected (id/behavior/traces/kind/state/target). The canonical format is the 4-column shape `zfa tdd plan <feature>` writes — re-run it to migrate; the 6-column dialect is accepted for one release.
zfa tdd run: feature 003-user-communication-interface — 26 behavior(s)
zfa tdd run: step failed — behavior=A1 step=gen outcome=runner-error
   cannot resolve the zfa entrypoint (package:zuraffa is not on the package path); pass --zfa-bin explicitly
```

## Symptom

`zfa tdd run` on a feature with a 6-column test-list prints a deprecation warning to stderr. The warning is appropriate for a migration path, but the behavior described — "the 6-column dialect is accepted for one release" — means the loop should proceed transparently without the warning, since the user did nothing wrong and the list is valid.

Additionally: the warning is worded as a migration instruction ("re-run `zfa tdd plan <feature>` to migrate") but `zfa tdd plan` writes `spec.md`, not `test-list.md`. The correct fix for a user with a 6-column list is to manually convert it to 4-column format — the warning's own instruction is incorrect.

## Reproduction

1. Have a project with a spec at `specs/003-user-communication-interface/tdd/test-list.md` using the 6-column format (`| id | behavior | traces | kind | state | target |`).
2. Run `zfa tdd run 003-user-communication-interface --project /path/to/project`.
3. Observe the deprecation warning printed to stderr before the run proceeds.

## Suspected Code Paths

- `lib/src/plugins/tdd/services/test_list_reader.dart:135-143` — `_readFromFile` prints the deprecation warning once per file (`deprecatedDialectWarned` guard) whenever it encounters 6-column rows. The rows are parsed correctly (returning `deprecated: true`), but the warning is printed unconditionally.
- `lib/src/plugins/tdd/services/test_list_reader.dart:185-234` — the two 6-column parsing branches both return `deprecated: true`, confirming the code intends to support the format for one release.
- `lib/src/plugins/tdd/commands/run_command.dart` — calls `TestListReader.read()` and receives the rows; does not suppress the warning.

## Root Cause Hypothesis

**Confidence: high.** The deprecation warning is printed unconditionally in `test_list_reader.dart` every time a 6-column row is encountered, with no configuration to suppress it. The intent of spec 050 is that 6-column lists are accepted for one release (so existing features are not broken), but the warning is verbose and alarming to users who have a valid 6-column list they did not create. The warning also gives incorrect migration advice (`zfa tdd plan` does not rewrite `test-list.md`).

## Proposed Remediation

**Preferred**: Suppress the deprecation warning by default, and only print it when the user explicitly opts into migration help. The simplest change is to gate the warning behind an environment variable or `--verbose` flag, so running CI pipelines and automated tools does not see the alarm.

Alternative: fix the warning text to give correct migration advice (manually convert 6-column to 4-column) rather than the incorrect "re-run `zfa tdd plan`" instruction.

**Files likely to change**:
- `lib/src/plugins/tdd/services/test_list_reader.dart` — gate the warning behind a flag

## Risks & Considerations

- The warning was added intentionally to nudge users off 6-column format. Removing it entirely would weaken the migration signal.
- A `--verbose` gate preserves the signal for users who want it while keeping normal runs clean.

## Open Questions

- [NEEDS CLARIFICATION: Should the warning be suppressed entirely, or only in CI/automated contexts? Should the migration text be corrected?]
