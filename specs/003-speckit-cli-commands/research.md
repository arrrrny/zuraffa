# Research: ZFA CLI Commands Implementation in Speckit Extension

## Overview

Research conducted to implement all ZFA CLI commands as Speckit extension commands.

## Commands Analysis

### Full ZFA CLI Command Inventory (26 commands)

| Command | Category | Subcommands | Purpose |
|---------|----------|-------------|---------|
| generate | Generation | - | Generate Clean Architecture code using presets |
| feature | Scaffolding | scaffold, controller, di, mock, presenter, route, state, test, view | Scaffold full features |
| initialize | Utilities | - | Initialize test entity |
| entity | Entity | - | Create Zorphy entities |
| create | Structure | - | Create architecture folders/pages |
| usecase | Domain | create | Generate UseCases |
| repository | Data | create, method | Generate Repositories |
| datasource | Data | create, inject, method, private-method | Generate DataSources |
| view | Presentation | create, custom, register | Generate Flutter Views |
| controller | Presentation | create | Generate Controllers |
| presenter | Presentation | create | Generate Presenters |
| service | Domain | create, method | Generate Services |
| provider | Domain | create, inject, method, private-method | Generate Providers |
| cache | Utilities | - | Generate Cache logic |
| di | Utilities | create, register | Generate DI registration |
| mock | Testing | create, data, inject, method | Generate Mocks |
| test | Testing | create | Generate Tests |
| state | State | create | Generate State classes |
| route | Navigation | create, custom | Generate route definitions |
| observer | State | create | Generate Observer |
| config | Management | - | Manage ZFA configuration |
| apply | Management | - | Execute previously generated plan |
| plugin | Management | - | Manage plugins |
| manifest | Utilities | - | List all available capabilities |
| validate | Utilities | - | Validate JSON configuration |
| doctor | Management | - | Show tooling info |
| shadcn | UI | - | Generate Shadcn UI widgets |
| make | Generation | - | Run multiple generator plugins |

## Extension Framework Analysis

### Speckit Extension Structure

Based on the existing `extension.yml` in zuraffa-speckit:

```yaml
provides:
  commands:
    - name: "speckit.zuraffa.{command}"
      file: "commands/{command}.md"
      description: "..."
      aliases: [...]
```

### Command Implementation Pattern

1. Each command is a markdown file in `commands/` directory
2. Command files contain prompt template and parameter definitions
3. Aliases provide alternative command names
4. Help text sourced from `zfa help {command}` output

## Implementation Decisions

### Decision: Command Organization

**Chosen**: Categorized by function (Generation, Scaffolding, Domain, Data, Presentation, Utilities, Testing, Management)

**Rationale**: Mirrors how developers think about tasks - by what they want to accomplish, not by the command name.

### Decision: Flag Handling

**Chosen**: Pass-through pattern - extension accepts parameters and forwards to zfa

**Rationale**: Maintains full CLI capability without reimplementing flag parsing.

### Decision: Help Documentation

**Chosen**: Generated from CLI --help output, cached in command files

**Rationale**: Ensures accuracy and easy updates when CLI changes.

## Alternatives Considered

1. **Direct CLI wrapper**: Would require more complex shell integration
2. **Dynamic command discovery**: Would add startup latency
3. **Simplified flag set**: Would lose functionality - rejected

## Research Complete

No NEEDS CLARIFICATION items remain. Implementation can proceed with full understanding of requirements.