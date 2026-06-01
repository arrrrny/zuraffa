# `.zfa/` Memory Guide

This guide explains how to use the `.zfa/` directory as project memory for AI agents and human developers.

## Overview

The `.zfa/` directory is Zuraffa v5's project memory surface. It stores:
- Generation plans and execution logs
- Architectural blueprints and patterns
- Decision records (ADRs)
- Feature manifests
- Project context and state

## Directory Structure

```
.zfa/
├── plans/          # Generation plans from `zfa make --plan`
├── runs/           # Execution logs and results
├── blueprints/     # Architectural blueprints and patterns
├── decisions/      # Architectural decision records (ADRs)
├── manifests/      # Feature manifests
└── context.json    # Project context and state
```

## File Formats

### `context.json`
Project-wide metadata and state.

**Example:**
```json
{
  "project": {
    "name": "my_app",
    "type": "flutter_app",
    "architecture": "clean_architecture",
    "version": "v5"
  },
  "zuraffa": {
    "version": "v5",
    "contract": "entity_create_make_build",
    "domainRoot": "lib/src/domain",
    "entityRoot": "lib/src/domain/entities"
  },
  "features": {
    "existing": ["user", "product", "order"],
    "migrated": ["user"],
    "pending": ["product", "order"]
  },
  "lastUpdated": "2026-06-01T09:00:00Z"
}
```

### `plans/`
Generation plans created with `zfa make --plan`.

**Naming:** `{entity}_{timestamp}.json` or `{entity}_{preset}_{timestamp}.json`

**Example:** `plans/product_crud_20260601_090000.json`

```json
{
  "entity": "Product",
  "preset": "crud",
  "plugins": ["repository", "datasource", "usecase", "di", "test"],
  "methods": ["get", "getList", "create", "update", "delete"],
  "options": {
    "with": ["vpc"],
    "state": true,
    "di": true,
    "test": true
  },
  "timestamp": "2026-06-01T09:00:00Z"
}
```

### `runs/`
Execution logs from `zfa make` runs.

**Naming:** `{entity}_{timestamp}.json` or `{entity}_{timestamp}.md`

**Example:** `runs/product_20260601_090500.json`

```json
{
  "entity": "Product",
  "command": "zfa make Product --preset=crud --with=vpc --state --di --test",
  "status": "success",
  "filesGenerated": 15,
  "filesModified": 3,
  "duration": "2.3s",
  "timestamp": "2026-06-01T09:05:00Z",
  "files": [
    "lib/src/domain/repositories/product_repository.dart",
    "lib/src/data/repositories/data_product_repository.dart",
    "..."
  ]
}
```

### `blueprints/`
Architectural blueprints and patterns.

**Naming:** `{blueprint_name}.md`

**Example:** `blueprints/app_architecture.md`

```markdown
# App Architecture Blueprint

**Type**: Flutter Application
**Architecture**: Clean Architecture
**Generation**: Zuraffa v5

## Overview
Brief description of the application architecture.

## Layers
- Domain: entities, repositories, usecases
- Data: datasources, repository implementations
- Presentation: presenters, controllers, views

## Key Patterns
- Repository pattern for data access
- UseCase pattern for business logic
- Presenter/Controller/View for UI
```

### `decisions/`
Architectural Decision Records (ADRs).

**Naming:** `{decision_name}.md`

**Example:** `decisions/manual-ui-zones.md`

```markdown
# ADR: Manual UI Zones

**Status**: Active
**Date**: 2026-06-01

## Decision
We maintain manual control over view composition while using Zuraffa for architecture generation.

## Rationale
- Generated architecture provides consistency
- View composition requires design decisions
- Platform-specific UI needs custom handling

## Boundaries
### Generated (Zuraffa owns)
- Entities, repositories, datasources, usecases
- Presenters, controllers, state
- DI, tests, mocks

### Manual (developers own)
- View widget composition
- Page layouts
- Styling and theming
- Platform-specific UI
```

### `manifests/`
Feature manifests describing feature boundaries and dependencies.

**Naming:** `{feature_name}_manifest.json`

**Example:** `manifests/product_manifest.json`

```json
{
  "feature": "product",
  "entities": ["Product"],
  "dependencies": ["user", "category"],
  "platforms": ["mobile", "web"],
  "status": "active",
  "owner": "team-commerce",
  "lastUpdated": "2026-06-01T09:00:00Z"
}
```

## Usage Patterns

### For AI Agents

**Before starting work:**
1. Read `context.json` to understand project state
2. Check `decisions/` for architectural constraints
3. Review `blueprints/` for patterns to follow
4. Check `runs/` for recent generation history

**During generation:**
1. Use `zfa make --plan` to create a plan in `plans/`
2. Review the plan before executing
3. Execute with `zfa make`
4. Execution log automatically saved to `runs/`

**After generation:**
1. Update `context.json` if project state changed
2. Create ADRs in `decisions/` for significant choices
3. Update blueprints if patterns evolved

### For Human Developers

**Project onboarding:**
1. Read `blueprints/` to understand architecture
2. Review `decisions/` to understand constraints
3. Check `context.json` for current state

**Before regenerating:**
1. Check `runs/` for previous generation results
2. Review `plans/` to understand what will change
3. Use `zfa make --plan` to preview changes

**After major changes:**
1. Document decisions in `decisions/`
2. Update blueprints if patterns changed
3. Update `context.json` if needed

## Best Practices

### Keep It Current
- Update `context.json` when project state changes
- Create ADRs for significant architectural decisions
- Document patterns in blueprints as they emerge

### Make It Useful
- Write ADRs that explain *why*, not just *what*
- Include examples in blueprints
- Keep run logs for debugging and history

### Keep It Clean
- Archive old plans and runs periodically
- Remove obsolete decisions (mark as "Superseded")
- Update blueprints when patterns change

## Integration with Zuraffa

### Automatic Integration
Currently, `.zfa/` is manually managed. Future versions will:
- Auto-write plans when using `--plan`
- Auto-write run logs after execution
- Auto-update `context.json` after generation

### Manual Integration
For now:
1. Create plans manually or with `--plan` flag
2. Document runs in `runs/` after generation
3. Update `context.json` manually
4. Create ADRs and blueprints as needed

## Migration from Legacy Projects

If migrating from pre-v5 Zuraffa:
1. Create `.zfa/` directory structure
2. Write initial `context.json`
3. Document existing architecture in blueprints
4. Create ADRs for key decisions
5. Use `zfa make` going forward

## Examples

See the `zik_zak` project for a complete example:
- `/Users/ahmettok/Developer/zik_zak/.zfa/`

Key files to review:
- `context.json` - Project state
- `blueprints/zik_zak_app.md` - App architecture
- `decisions/manual-ui-zones.md` - Generated vs manual boundaries
- `decisions/platform-shell-strategy.md` - Platform-specific UI strategy
