# Bug Assessment: `zfa tdd run` rejects path-format spec references

- **Slug**: `tdd-run-rejects-path-format`
- **Created**: 2026-08-31
- **Source**: pasted text (user-reported)
- **Verdict**: valid
- **Severity**: low

## Report (verbatim)

```
✗ Ran a command
   $ cd /Users/ahmettok/Developer/forklift
     zfa tdd run specs/003-user-communication-interface --project /Users/ahmettok/Developer/forklift 2>&1
   ❌ invalid feature "specs/003-user-communication-interface": expected a single spec directory name such as 049-tdd-run, not a path.
   zfa tdd run <feature> [--project <dir>] [--zfa-bin <path>]
   Command failed with exit code: 64.
```

## Symptom

When a user passes `specs/<feature>` (the standard path format shown throughout zuraffa's own spec documentation, error messages, and output) to `zfa tdd run`, the command rejects it with a `UsageException`. The command only accepts a bare feature directory name (e.g. `003-user-communication-interface`), not a relative path.

## Reproduction

1. Have a project with a spec at `specs/003-user-communication-interface/`.
2. Run `zfa tdd run specs/003-user-communication-interface --project /path/to/project`.
3. Observe exit code 64 with the error `invalid feature "specs/003-user-communication-interface": expected a single spec directory name such as 049-tdd-run, not a path.`

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/run_command.dart:835-845` (`_validateFeatureSegment`) — validates that `feature` contains no path separators (`/`, `\`), rejecting `specs/<feature>` inputs.
- `lib/src/plugins/tdd/commands/run_command.dart:147` — constructs `featureDir` as `projectRoot / 'specs' / feature`. If `specs/` is already in the input, this produces `specs / specs / <feature>`, which won't exist.
- `lib/src/plugins/tdd/commands/verify_red_command.dart:461-472` — the same guard in the `verify-red` subcommand.

## Root Cause Hypothesis

**Confidence: high.** The `_validateFeatureSegment` guard intentionally blocks paths to prevent `..` traversal attacks. However, it is over-restrictive: it also blocks the legitimate `specs/<feature>` prefix that appears in every spec's own documentation, in the TDD cycle-log entries, and in error messages that reference spec paths. Users naturally copy spec identifiers from these contexts and include the `specs/` prefix, causing a needless failure. The underlying logic at line 147 already handles bare names correctly by prepending `specs/`.

## Proposed Remediation

**Preferred**: Normalize the input by stripping a leading `specs/` prefix before validation and before path construction. Change `run_command.dart`:

1. Before `_validateFeatureSegment(feature)` is called, strip any `specs/` prefix:
   ```dart
   final feature = rest.first.startsWith('specs/')
       ? rest.first.substring('specs/'.length)
       : rest.first;
   ```
2. Apply the same normalization in `verify_red_command.dart` for the `--feature` flag.

This preserves the security guarantee (no `..` traversal) while accepting the canonical path format users naturally provide. The `featureDir` construction at line 147 remains unchanged — it still appends `specs/` to the now-normalized bare name.

**Alternative**: Update error messages to show the expected bare-name format prominently, and ensure all internal documentation consistently uses bare names. Lower priority since users will still hit the error when copy-pasting from paths.

**Files likely to change**:
- `lib/src/plugins/tdd/commands/run_command.dart` (strip `specs/` prefix)
- `lib/src/plugins/tdd/commands/verify_red_command.dart` (same normalization)

**Tests to add or update**:
- Add a test in `test/plugins/tdd/` that invokes `run` with a `specs/<feature>` input and verifies it resolves correctly (accepts it, finds the feature dir, does not throw `UsageException`).

## Risks & Considerations

- The normalization must handle edge cases: `specs/` alone is not a feature name; `specs/../../../etc/passwd` stripped to `../../../etc/passwd` would still fail the `..` guard — the existing traversal guard remains the last line of defense.
- `verify_red_command.dart` has its own `--feature` flag with the same issue; fix both for consistency.
- No API or contract change — `zfa tdd run 003-user-communication-interface` still works identically.

## Open Questions

- None.
