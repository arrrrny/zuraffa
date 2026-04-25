# Interface Contracts: Zuraffa Speckit Extension

## Overview

This extension exposes ZFA CLI commands through the Speckit command interface.

## Exposed Interface

### Command Interface

The extension provides commands following the pattern: `speckit.zuraffa.<command>`

```
speckit.zuraffa.generate <args>
speckit.zuraffa.feature <args>
speckit.zuraffa.entity <args>
...
```

### Parameter Contract

Commands accept:
- Entity name (positional argument)
- CLI flags (forwarded to zfa)
- Subcommands (passed through)

### Output Contract

Commands return:
- CLI stdout output (preserved)
- CLI exit code (passed through)
- Error messages (on failure)

### Contract with Speckit System

| Aspect | Contract |
|--------|----------|
| Command registration | Via extension.yml provides.commands |
| Execution | Shell invocation of `dart run zuraffa:zfa ...` |
| Help retrieval | Via `zfa help <command>` |
| Output format | Text (default) or JSON (via --format flag) |

### Error Handling

| Condition | Behavior |
|-----------|----------|
| zfa not found | Return error: "ZFA CLI not found in PATH" |
| Invalid command | Pass through CLI error message |
| Invalid flags | Pass through CLI validation error |
| Command timeout | Pass through (no timeout override) |

## Implementation Notes

- Commands are passthrough wrappers - no local validation
- All flags and subcommands are passed directly to CLI
- Extension help is sourced from CLI --help output
- JSON output format matches CLI --format=json