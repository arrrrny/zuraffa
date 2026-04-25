# Data Model: ZFA CLI Commands Extension

## Overview

Data model defining the structure of the Speckit extension commands.

## Core Entities

### ZFACommand

Represents a ZFA CLI command that can be invoked through the extension.

| Field | Type | Description |
|-------|------|-------------|
| name | String | Command name (e.g., "generate", "feature") |
| category | CommandCategory | Functional category |
| description | String | Brief description |
| subcommands | List<String> | Available subcommands |
| flags | List<CommandFlag> | Available CLI flags |
| aliases | List<String> | Alternative command names |
| helpText | String | Full help documentation |

### CommandCategory

Groups related commands.

| Category | Commands Included |
|----------|------------------|
| Generation | generate, make, initialize |
| Scaffolding | feature |
| Domain | usecase, service, provider |
| Data | repository, datasource |
| Presentation | view, controller, presenter, state, observer, route |
| Utilities | cache, manifest, validate, config |
| Testing | test, mock |
| Management | apply, plugin, doctor, shadcn |
| Structure | create, entity |

### CommandFlag

Represents a CLI flag/option.

| Field | Type | Description |
|-------|------|-------------|
| name | String | Flag name (e.g., "dry-run", "force") |
| short | String? | Short form (e.g., "-f") |
| type | FlagType | Boolean, string, or list |
| required | Boolean | Whether flag is required |
| default | String? | Default value if optional |
| description | String | Help text |

### CommandRegistry

Maps extension commands to their ZFA CLI equivalents.

```yaml
registry:
  speckit.zuraffa.generate:
    cli: "dart run zuraffa:zfa generate"
    args: "<name> [options]"
  speckit.zuraffa.feature.scaffold:
    cli: "dart run zuraffa:zfa feature scaffold"
    args: "<entity> [options]"
  # ... etc
```

## Validation Rules

- Each command MUST have a unique name
- Command names MUST follow pattern: `speckit.zuraffa.{command}`
- Flags MUST match the ZFA CLI flag specifications
- Help text MUST be synchronized with CLI --help output

## State Transitions

This extension is stateless - each invocation is independent.

## Relationships

```
CommandRegistry → ZFACommand (1:N)
ZFACommand → CommandCategory (N:1)
ZFACommand → CommandFlag (1:N)
```