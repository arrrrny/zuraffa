# Quickstart: Zuraffa Speckit Extension

## Prerequisites

- Zuraffa CLI installed (`dart run zuraffa:zfa` or `zfa` in PATH)
- Speckit extension framework installed

## Installation

The extension is already added as a git submodule:

```bash
# Already configured at:
.specify/extensions/zuraffa/
```

## Usage

### Available Commands

| Command | Description |
|---------|-------------|
| `speckit.zuraffa.generate` | Generate Clean Architecture code |
| `speckit.zuraffa.feature` | Scaffold full features |
| `speckit.zuraffa.entity` | Create Zorphy entities |
| `speckit.zuraffa.usecase` | Generate UseCases |
| `speckit.zuraffa.repository` | Generate Repositories |
| `speckit.zuraffa.datasource` | Generate DataSources |
| `speckit.zuraffa.view` | Generate Flutter Views |
| `speckit.zuraffa.controller` | Generate Controllers |
| `speckit.zuraffa.presenter` | Generate Presenters |
| `speckit.zuraffa.service` | Generate Services |
| `speckit.zuraffa.provider` | Generate Providers |
| `speckit.zuraffa.cache` | Generate Cache logic |
| `speckit.zuraffa.di` | Generate DI registration |
| `speckit.zuraffa.mock` | Generate Mocks |
| `speckit.zuraffa.test` | Generate Tests |
| `speckit.zuraffa.state` | Generate State classes |
| `speckit.zuraffa.route` | Generate route definitions |
| `speckit.zuraffa.observer` | Generate Observer |
| `speckit.zuraffa.config` | Manage ZFA configuration |
| `speckit.zuraffa.apply` | Execute previously generated plan |
| `speckit.zuraffa.plugin` | Manage plugins |
| `speckit.zuraffa.manifest` | List all available capabilities |
| `speckit.zuraffa.validate` | Validate JSON configuration |
| `speckit.zuraffa.doctor` | Show tooling info |
| `speckit.zuraffa.shadcn` | Generate Shadcn UI widgets |
| `speckit.zuraffa.make` | Run multiple generator plugins |
| `speckit.zuraffa.create` | Create architecture folders/pages |
| `speckit.zuraffa.initialize` | Initialize test entity |

### Example Usage

```bash
# Generate a Product entity with CRUD
speckit.zuraffa.generate Product --methods=get,getList,create,update,delete --vpcs --state

# Scaffold a full feature
speckit.zuraffa.feature scaffold Product --vpcs --di --test

# Get help for a command
speckit.zuraffa.generate --help

# Use dry-run to preview
speckit.zuraffa.generate Product --dry-run
```

### Help

Get help for any command:

```bash
speckit.zuraffa.<command> --help
```

### Categories

Commands are organized by category:

- **Generation**: generate, make, initialize
- **Scaffolding**: feature
- **Domain**: usecase, service, provider
- **Data**: repository, datasource
- **Presentation**: view, controller, presenter, state, observer, route
- **Utilities**: cache, manifest, validate, config
- **Testing**: test, mock
- **Management**: apply, plugin, doctor, shadcn
- **Structure**: create, entity