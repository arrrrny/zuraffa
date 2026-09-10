# Chore Assessment: Improve readability of zfa tdd help text

- **Slug**: zfa-tdd-help-readability
- **Created**: 2026-09-10
- **Source**: pasted text
- **Verdict**: in scope
- **Size**: small

## Report (verbatim or summarized)

> when I run zfa tdd and hit enter on the command to see the help text, it is not readable, the issue ise commands should lined on a column and descriptions should never pass into the commands column. improve readability by commands always list without description text getting along here is an example of issue: ~/D/zuraffa ❯❯❯ zfa tdd
> ❌ Missing subcommand for "zfa tdd".
> Usage: zfa tdd <subcommand> [options]
> -h, --help    Print this usage information.
> 
> Available subcommands:
>   compose         Compose an acceptance behavior's subject against the feature's green unit subjects — the composition step of the acceptance make pipeline (issue #642, spec 052).
>   corpus          Drive the whole spec corpus through the TDD loop: batch run with resume, per-feature verify gate, provenance audit, and the gap ledger (spec 051).
>   diff-check      Check fixture parity between the mock and real adapters for the feature's committed adapter contracts; drift = named verdict, exit 2 (bug #915).
>   doctor          Diagnose a feature's TDD stores and prescribe exactly one recovery action — migrate (another feature owns the legacy-layout files), adopt (register unowned generated files), reset (drop stale registry records), or resume (re-run the loop) — as a --> fix: line with a JSON verdict (bugs #840, #874).
>   fake            Generate a framework-certified fake for a platform channel: a test-side handler (TestDefaultBinary

## Summary

The `zfa tdd` help text (and likely other command help texts) is unreadable because the `args` package's `CommandRunner` is instantiated without a `usageLineLength`, causing no line wrapping. Long descriptions exceed terminal width and break column alignment, making the output difficult to scan.

## Constitution Check

No constitution file exists. This chore is a maintenance improvement that does not violate any known project constraints.

## Affected Paths

- `lib/src/cli/cli_runner.dart:120` — where `_CrashSafeCommandRunner` is constructed without `usageLineLength`.

## Proposed Approach

**Preferred**: Add `usageLineLength: 100` (or 80) to the `_CrashSafeCommandRunner` constructor call in `_buildRunner()`. This will cause the `args` package to wrap help text at the specified column, ensuring descriptions are properly wrapped and column alignment is preserved.

The change is a one-line modification:

```dart
static CommandRunner<void> _buildRunner() =>
    _CrashSafeCommandRunner(
        'zfa',
        'Zuraffa Code Generator - Clean Architecture for Flutter',
        usageLineLength: 100,  // <-- add this
      )
```

**Alternatives**:
- Use 80 columns (standard terminal width) — may be too narrow for some descriptions.
- Detect terminal width dynamically — more complex and may not be necessary.

**Paths likely to change**:
- `lib/src/cli/cli_runner.dart`

**Verification to run**:
- `dart analyze` to ensure no static analysis issues.
- Run existing tests (`dart test`) to ensure no regressions.
- Manually run `zfa tdd` and observe the help text formatting; also run `zfa --help` and other commands to ensure readability across the CLI.

## Risks & Considerations

- Changing the line length globally affects all command help outputs, which is desirable for consistency.
- The chosen line length (100) should be tested on typical terminal widths (80-120 columns).
- The `args` package's wrapping algorithm may produce slightly different line breaks; manual verification is needed.

## Open Questions

- [NEEDS CLARIFICATION: Is 100 columns the optimal line length, or should we use 80?] (The assessment assumes 100, but can be adjusted during implementation.)