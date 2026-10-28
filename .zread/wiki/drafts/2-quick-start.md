Welcome to Zuraffa — the AI-first Clean Architecture framework for Flutter and Dart. This guide takes you from a blank terminal to a compilable, generated architecture in minutes, using the canonical v7 workflow. Every step is a single command; no manual boilerplate is required.

> **Prerequisite**: Dart SDK `^3.11.0` and (for Flutter apps) Flutter installed. Verify with `dart --version` and `flutter --version`.

**What you'll do**: install the CLI, scaffold a project, create an entity, generate the architecture around it, and build it. By the end you will have a fixed-layout Clean Architecture stack under `lib/src/` that compiles and is ready for implementation.

Sources: [README.md](README.md#L1-L39), [pubspec.yaml](pubspec.yaml#L1-L4)

---

## The Canonical v7 Workflow

Zuraffa v7 standardizes all code generation around one three-step workflow:

```text
zfa entity create  →  zfa make  →  zfa build
```

| Step | Command | Purpose |
|---|---|---|
| **1. Entity** | `zfa entity create` | Define a Zorphy entity — an immutable, typed domain object |
| **2. Make** | `zfa make` | Generate the full architecture around the entity (repositories, use cases, DI, tests, …) |
| **3. Build** | `zfa build` | Run the codegen/build step (replaces calling `build_runner` directly) |

`zfa feature scaffold` still exists, but only as a wrapper over `zfa make --preset=feature`. Always prefer `zfa make` as the primary generator.

```mermaid
flowchart LR
    A["zfa entity create -n Product"] --> B["zfa make Product --preset=crud"]
    B --> C["zfa build"]
    C --> D["Compilable architecture"]

    subgraph "Input"
        A
    end
    subgraph "Generation"
        B
    end
    subgraph "Verification"
        C
    end
```

The pipeline rule for humans and AI agents is simple: if a new entity is needed, use `zfa entity create`; if the architecture skeleton needs to exist or change, use `zfa make`; if generated annotations/build outputs need to be finalized, use `zfa build`. Zuraffa owns the architecture skeleton; hand-crafted work narrows to business logic, datasource implementation, styling, and manual UI composition after that pipeline runs.

Sources: [README.md](README.md#L10-L16), [README.md](README.md#L275-L293), [SKILL.md](SKILL.md#L25-L42)

---

## Step 0 — Install

### Add Zuraffa to your project

```yaml
# pubspec.yaml
dependencies:
  zuraffa: ^7.2.0

dev_dependencies:
  zuraffa: ^7.2.0
  zorphy_annotation: ^1.7.0
  build_runner: ^2.4.0
```

### Install the CLI globally

```bash
dart pub global activate zuraffa
zfa --version
```

Alternatively, run the CLI from the repo source during development:

```bash
cd ~/Developer/zuraffa
scripts/zfa --help
```

> **No-JIT policy**: The CLI must always run as a **compiled binary**, never through the Dart VM interpreter. `dart bin/zfa.dart` is reserved for `dart test` itself. The sanctioned entry point is `scripts/zfa` (or the installed `~/.local/bin/zfa`), which compiles once into `.dart_tool/zfa_cli_bin/zfa_exe` and reuses it. See `scripts/zfa` for the freshness and copy-if-fresh tiers.

Sources: [README.md](README.md#L55-L75), [scripts/zfa](scripts/zfa#L1-L40), [pubspec.yaml](pubspec.yaml#L1-L4)

---

## Step 1 — Bootstrap a New Project

Use `zfa setup` to create a new Flutter or Dart project with the Zuraffa dependency set already wired in:

```bash
zfa setup my_app --flutter --org=com.example
```

| Flag | Purpose |
|---|---|
| `--flutter` | Create a Flutter app (default) |
| `--dart` | Create a pure Dart package |
| `--org=com.example` | Organization identifier for Flutter creation |
| `--platforms=ios,android` | Target platforms |
| `--deep-link-scheme=gozuzu` | Pre-seed a URL scheme for deep links |
| `--specs=dir` | Import a spec corpus for TDD from day zero |
| `--dry-run` | Preview without writing files |
| `--no-git` | Skip git initialization |
| `--force` | Delete and recreate the target directory if it exists |
| `--tdd-example` | Emit an additional failing example test |

The `setup` command performs 9 sequential steps:

1. Creates the app (`flutter create` / `dart create`)
2. Wires zuraffa dependencies into `pubspec.yaml`
3. Creates `build.yaml` + domain directory structure
4. Creates default `.zfa.json`
5. Pre-seeds deep-link scheme (Flutter only)
6. Emits TDD day-zero baseline (Flutter only)
7. Imports spec corpus (if `--specs` provided)
8. Generates app shell (Flutter only)
9. Prints summary + next steps

After setup, navigate into the project and fetch dependencies:

```bash
cd my_app
dart pub get --no-example
```

Sources: [lib/src/commands/setup_command.dart](lib/src/commands/setup_command.dart#L33-L144), [README.md](README.md#L76-L93)

---

## Step 2 — Understand the Project Layout

Zuraffa v7 assumes a **fixed architecture root**. All generated code lives under `lib/src/`:

```text
lib/src/
├── domain/
│   ├── entities/          # Zorphy entities
│   ├── repositories/      # Repository interfaces/implementations
│   └── usecases/          # Business logic (UseCase pattern)
├── data/                  # Data sources, API clients, local storage
├── di/                    # Dependency injection registrations
└── presentation/          # UI layer (views, presenters, controllers, state)
```

Entity files must live at:

```text
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

Example: `lib/src/domain/entities/product/product.dart`.

Configuration is split across two surfaces:

| File | Purpose | Mental Model |
|---|---|---|
| `.zfa.json` | Active project defaults (plugin defaults, entity-first rules) | "What this project prefers by default" |
| `.zfa/` | Project memory (plans, runs, decisions, blueprints, manifests, receipts) | "What has been planned, generated, and decided over time" |

Canonical `.zfa/` layout:

```text
.zfa/
├── plans/
├── runs/
├── blueprints/
├── decisions/
├── manifests/
├── receipts/
└── context.json
```

Sources: [README.md](README.md#L133-L191), [AGENTS.md](AGENTS.md#L74-L98)

---

## Step 3 — Create an Entity

Entities are always created first — they are the foundation of every architecture:

```bash
zfa entity create -n Product \
  --field id:String \
  --field name:String \
  --field price:double \
  --field description:String?
```

| Flag | Description |
|---|---|
| `-n, --name` | Entity name (PascalCase) |
| `--field <name>:<type>` | Field with Dart type (`?` suffix for nullable) |
| `--kind=value_object` | Create a value object (no identity required) |
| `--auto-id` | Auto-generate `String id` with `Uuid().v4()` |
| `--allow-forward-refs` | Allow fields referencing not-yet-created entities |

> **Id-less entities fail loudly**: Every entity needs an `id` / `*Id` field. Use `--auto-id` for auto-generated IDs, or `--kind=value_object` for identity-less composition types.

### Create an enum

```bash
zfa entity enum -n OrderStatus --value pending,paid,shipped
```

### Add a field to an existing entity

```bash
zfa entity add-field -n Product --field stock:int
```

Sources: [lib/src/commands/entity_command.dart](lib/src/commands/entity_command.dart#L1880-L1960), [CLI_GUIDE.md](CLI_GUIDE.md#L153-L193)

---

## Step 4 — Generate Architecture with `make`

`zfa make` is the canonical architecture generator. It produces the domain, data, presentation, and test layers around your entity:

```bash
zfa make Product \
  --preset=crud \
  --methods=get,getList,create,update,delete \
  --with=vpc \
  --state \
  --di \
  --test
```

| Flag | Purpose |
|---|---|
| `--preset=crud` | Architecture pattern (crud, feature, etc.) |
| `--methods=...` | Comma-separated list: `get,getList,create,update,delete` |
| `--with=vpc` | Generate View/Presenter/Controller layer |
| `--state` | Generate state management |
| `--di` | Generate dependency injection registrations |
| `--test` | Generate unit tests |
| `--cache` | Add local cache/persistence (Hive) |
| `--mock` | Generate mock datasource |
| `--route` | Generate route |
| `--plan` | Print the normalized execution plan and exit |
| `--format=json` | Emit plan output as JSON |

### Preview before writing

```bash
zfa make Product --preset=crud --with=vpc --plan --format=json
```

### Custom use case

```bash
zfa make SearchProducts usecase --domain=search --params=SearchQuery --returns=List<Product>
```

Sources: [lib/src/commands/make_command.dart](lib/src/commands/make_command.dart#L209-L395), [README.md](README.md#L91-L105), [CLI_GUIDE.md](CLI_GUIDE.md#L64-L82)

---

## Step 5 — Build the Generated Code

```bash
zfa build
```

This replaces calling `build_runner` directly in all docs, agent workflows, and CI pipelines. It:

- Runs `zuraffa_build` (code generation from annotations)
- Runs `dart analyze` after build (fails on errors by default)
- Optionally runs the DDA `@Route` stage for compile-time routing validation

Use `--clean` to delete the build cache before building, or `--force` to regenerate all files from scratch:

```bash
# Clean build when you suspect stale cache
zfa build --clean

# Force full regeneration
zfa build --force
```

Sources: [README.md](README.md#L107-L115), [docs/openwiki/cli.md](docs/openwiki/cli.md#L103-L125)

---

## Step 6 — TDD Cycle (Spec-Driven Development)

For features requiring test-driven development, Zuraffa provides a spec-driven TDD engine. This is optional for the quick start but recommended for production features.

### Initialize TDD baseline

```bash
zfa tdd init
```

This sets up `test/`, `dart_test.yaml` (slow-tier tags + integration preset), and `.specify/memory/tdd-profile.md`. Verify the profile picked the right runner for your project type (Flutter → `flutter_test`, Dart → `dart test`).

### Author a spec

Create `specs/<feature>/spec.md` with acceptance scenarios and functional requirements.

### Run the TDD cycle

```bash
zfa tdd plan <feature>      # Derive behaviors from spec criteria
zfa tdd run <feature>       # Drive each behavior: gen → red → make → refactor
zfa tdd status <feature>    # Check if all behaviors are green
zfa tdd verify <feature>    # Audit test discipline + strength
```

> **STOP-ON-ROADBLOCK RULE**: The first time a `zfa` command errors or produces unexpected output, stop immediately. Report it as a Zuraffa gap — file an issue with command / expected / actual / root cause — then apply the minimum workaround needed.

Sources: [docs/zfa-tdd-guide.md](docs/zfa-tdd-guide.md#L1-L30), [AGENTS.md](AGENTS.md#L44-L72)

---

## Step 7 — Run and Verify

### Run tests

```bash
# All tests
dart test

# Flutter tests
flutter test

# TDD-driven tests for a specific feature
zfa tdd run <feature>
```

### Check project health

```bash
zfa doctor        # Inspect tooling and project health
zfa manifest      # Inspect available plugins and capabilities
zfa config        # View/edit `.zfa.json` defaults
```

Sources: [README.md](README.md#L392-L399)

---

## Complete Example: From Zero to Working App

Here is the entire flow from an empty project to a working CRUD architecture:

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant CLI as zfa CLI
    participant Build as build_runner

    Dev->>CLI: zfa setup my_app --flutter
    CLI->>Dev: Flutter app + zuraffa wired

    Dev->>CLI: zfa entity create -n Todo ...
    CLI->>Dev: lib/src/domain/entities/todo/todo.dart

    Dev->>CLI: zfa make Todo --preset=crud --with=vpc,state,di,test
    CLI->>Dev: repositories, usecases, controllers, tests, DI

    Dev->>Build: zfa build
    Build->>Dev: Compilable generated code

    Dev->>Dev: dart test / flutter test
    Dev->>Dev: ✅ Green
```

The resulting file structure:

```text
my_app/
├── .zfa.json
├── pubspec.yaml
├── lib/
│   └── src/
│       ├── domain/
│       │   └── entities/
│       │       └── todo/
│       │           └── todo.dart
│       ├── data/
│       │   ├── datasources/
│       │   └── repositories/
│       ├── di/
│       └── presentation/
│           ├── controllers/
│           ├── pages/
│           └── state/
├── test/
└── specs/
```

Sources: [README.md](README.md#L77-L115)

---

## Next Steps

Now that you have the workflow down, deepen your knowledge in this recommended order:

1. **[Overview](1-overview)** — Understand Zuraffa's philosophy and scope
2. **[Installation & Environment Setup](3-installation-and-environment-setup)** — Tooling, SDK versions, and environment
3. **[Canonical CLI Workflow](4-canonical-cli-workflow)** — Deep dive into entity → make → build
4. **[Project Layout & Fixed Architecture Root](5-project-layout-and-fixed-architecture-root)** — Layer responsibilities
5. **[Configuration & Project Memory](6-configuration-and-project-memory)** — Master `.zfa.json` and `.zfa/`
6. **[Running Tests & Local CI](7-running-tests-and-local-ci)** — Test execution and CI integration
7. **[Architecture Overview](8-architecture-overview)** — Core subsystem map
8. **[Code Generation Pipeline](9-code-generation-pipeline)** — How generation produces files
9. **[Plugin System & Manifest](10-plugin-system-and-manifest)** — Extend the generator
10. **[Entity & Zorphy Model](11-entity-and-zorphy-model)** — Entity features in depth
11. **[TDD & Spec-Driven Loop](16-tdd-and-spec-driven-loop)** — Full spec-driven TDD workflow
12. **[Proof & Provenance](17-proof-and-provenance)** — Generation receipts and verification gates

For migrating an existing package, see [Writing Zuraffa Packages](docs/writing_zuraffa_packages.md) or the [Package Migration Guide](docs/package_migration_guide.md).

Sources: [README.md](README.md#L392-L399)

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `zfa: command not found` | Run `dart pub global activate zuraffa` or use `scripts/zfa` from the repo |
| `No .zfa.json found` | Run `zfa config init` or `zfa setup <name>` in the project root |
| `Zuraffa package not found` | Add `zuraffa` to `dependencies` and run `dart pub get` |
| Generated code won't compile | Run `zfa build --clean` to force regeneration |
| TDD profile picked wrong runner | Edit `Keys.runner` in `.specify/memory/tdd-profile.md` |
| Stale binary warning | Run `scripts/rebuild.sh` to reinstall the system binary |