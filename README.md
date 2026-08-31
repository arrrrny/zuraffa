# 🦒 Zuraffa 

[![Pub Version](https://img.shields.io/pub/v/zuraffa)](https://pub.dev/packages/zuraffa)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Documentation](https://img.shields.io/badge/docs-docusaurus-blue)](https://arrrrny.github.io/zuraffa/)
[![zread](https://img.shields.io/badge/Ask_Zread-_.svg?style=flat&color=00b0aa&labelColor=000000&logo=data%3Aimage%2Fsvg%2Bxml%3Bbase64%2CPHN2ZyB3aWR0aD0iMTYiIGhlaWdodD0iMTYiIHZpZXdCb3g9IjAgMCAxNiAxNiIgZmlsbD0ibm9uZSIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj4KPHBhdGggZD0iTTQuOTYxNTYgMS42MDAxSDIuMjQxNTZDMS44ODgxIDEuNjAwMSAxLjYwMTU2IDEuODg2NjQgMS42MDE1NiAyLjI0MDFWNC45NjAxQzEuNjAxNTYgNS4zMTM1NiAxLjg4ODEgNS42MDAxIDIuMjQxNTYgNS42MDAxSDQuOTYxNTZDNS4zMTUwMiA1LjYwMDEgNS42MDE1NiA1LjMxMzU2IDUuNjAxNTYgNC45NjAxVjIuMjQwMUM1LjYwMTU2IDEuODg2NjQgNS4zMTUwMiAxLjYwMDEgNC45NjE1NiAxLjYwMDFaIiBmaWxsPSIjZmZmIi8%2BCjxwYXRoIGQ9Ik00Ljk2MTU2IDEwLjM5OTlIMi4yNDE1NkMxLjg4ODEgMTAuMzk5OSAxLjYwMTU2IDEwLjY4NjQgMS42MDE1NiAxMS4wMzk5VjEzLjc1OTlDMS42MDE1NiAxNC4xMTM0IDEuODg4MSAxNC4zOTk5IDIuMjQxNTYgMTQuMzk5OUg0Ljk2MTU2QzUuMzE1MDIgMTQuMzk5OSA1LjYwMTU2IDE0LjExMzQgNS42MDE1NiAxMy43NTk5VjExLjAzOTlDNS42MDE1NiAxMC42ODY0IDUuMzE1MDIgMTAuMzk5OSA0Ljk2MTU2IDEwLjM5OTlaIiBmaWxsPSIjZmZmIi8%2BCjxwYXRoIGQ9Ik0xMy43NTg0IDEuNjAwMUgxMS4wMzg0QzEwLjY4NSAxLjYwMDEgMTAuMzk4NCAxLjg4NjY0IDEwLjM5ODQgMi4yNDAxVjQuOTYwMUMxMC4zOTg0IDUuMzEzNTYgMTAuNjg1IDUuNjAwMSAxMS4wMzg0IDUuNjAwMUgxMy43NTg0QzE0LjExMTkgNS42MDAxIDE0LjM5ODQgNS4zMTM1NiAxNC4zOTg0IDQuOTYwMVYyLjI0MDFDMTQuMzk4NCAxLjg4NjY0IDE0LjExMTkgMS42MDAxIDEzLjc1ODQgMS42MDAxWiIgZmlsbD0iI2ZmZiIvPgo8cGF0aCBkPSJNNCAxMkwxMiA0TDQgMTJaIiBmaWxsPSIjZmZmIi8%2BCjxwYXRoIGQ9Ik00IDEyTDEyIDQiIHN0cm9rZT0iI2ZmZiIgc3Ryb2tlLXdpZHRoPSIxLjUiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPgo8L3N2Zz4K&logoColor=ffffff)](https://zread.ai/arrrrny/zuraffa)

**The AI-first Clean Architecture framework for Flutter.**

Zuraffa v5 standardizes code generation around one canonical workflow:

1. `zfa entity create`
2. `zfa make`
3. `zfa build`

`zfa make` is the primary generation surface. `zfa feature` still exists, but only as a wrapper over the normalized feature preset.

---

## Sponsor

[![https://zuzu.dev](./assets/zikzak-ai.png)](https://zuzu.dev) [![Sponsored by ZikZak AI](https://img.shields.io/badge/Sponsored%20by-ZikZak%20AI-8A2BE2?style=flat-square&logo=heart)](https://zuzu.dev)

Thanks to ZikZak AI for sponsoring this project!

ZikZak AI is an AI-Powered Price Comparison app that you scan barcodes, and discover amazing savings instantly. Your personal shopping assistant that never sleeps.

<a href="https://apps.apple.com/tr/app/zik-zak/id1563425450"><img src="assets/app-store-badge.png" width="160" style="margin-right: 8px;"></a>
<a href="https://play.google.com/store/apps/details?id=dev.zuzu.zingo"><img src="assets/google-play-badge.png" width="160"></a>

## Why Zuraffa?

- **AI-native**: predictable structure for humans and coding agents.
- **Clean Architecture by default**: domain, data, presentation, and DI stay consistent.
- **Zorphy-first entities**: immutable, typed entities generated under a fixed domain root.
- **Deterministic generation**: presets, aliases, `--with`, and `--without` resolve through the same plan system.
- **Result-based failures**: generated code uses `Result<T, AppFailure>` patterns throughout.
- **Hermetic-friendly workflows**: docs and tests are aligned around the current v5 surface.

---

## Scope

`zfa` is scoped to **Zuraffa apps** — packages that depend on
`zuraffa`/`zorphy_annotation` and carry a `.zfa.json`. The CLI generates
clean-architecture code inside that contract and nothing else: it
does not rewrite existing non-Zuraffa Flutter packages or plugins, and
`zfa doctor` reporting missing Zuraffa dependencies inside such a package
is expected behavior. Rewriting a non-Zuraffa plugin stays hand-written
work unless you file a feature request for that support. See the
[CLI guide](CLI_GUIDE.md#scope-what-zfa-operates-on) for details.

---

## Installation

Add Zuraffa to your project:

```yaml
dependencies:
  zuraffa: ^5.0.0

dev_dependencies:
  zuraffa: ^5.0.0
  zorphy_annotation: ^1.7.0
  build_runner: ^2.4.0
```

Install the CLI globally if you want `zfa` on your PATH:

```bash
dart pub global activate zuraffa
```

---

## Quick Start: the canonical v5 flow

### 1. Create an entity

Entities are always generated under `lib/src/domain/entities` in v5.

```bash
zfa entity create -n Product \
  --field id:String \
  --field name:String \
  --field price:double \
  --field description:String?
```

### 2. Generate architecture with `make`

Use `zfa make` as the default way to build the architecture around that entity.

```bash
zfa make Product \
  --preset=crud \
  --methods=get,getList,create,update,delete \
  --with=vpc \
  --state \
  --di \
  --test
```

That expands to a normalized plan that generates the domain, data, presentation, and test layers for `Product`.

### 3. Run the build step

```bash
zfa build
```

Use `zfa build` instead of calling `build_runner` directly in docs and agent workflows.

---

## Core v5 commands

| Command                | Role in v5                                 |
| ---------------------- | ------------------------------------------ |
| `zfa entity create`    | Define or update Zorphy entities           |
| `zfa make`             | Canonical architecture generator           |
| `zfa build`            | Run the codegen/build step                 |
| `zfa feature scaffold` | Wrapper over the normalized feature preset |
| `zfa config`           | Manage `.zfa.json` project defaults        |
| `zfa manifest`         | Inspect available plugins and capabilities |
| `zfa doctor`           | Inspect local tooling and project health   |

---

## Fixed project layout

Zuraffa v5 assumes a fixed architecture root:

```text
lib/src/
├── data/
├── di/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
```

Entity files must live at:

```text
lib/src/domain/entities/{entity_snake}/{entity_snake}.dart
```

Example:

```text
lib/src/domain/entities/product/product.dart
```

---

## `.zfa.json` defaults and `.zfa/` project memory

Zuraffa v5 separates **project defaults** from **project memory**:

- **`.zfa.json`**: active project configuration such as plugin defaults and entity-first rules.
- **`.zfa/`**: the canonical v5 project-memory model for plans, runs, decisions, blueprints, manifests, and future agent context.

A useful mental model for humans and AI agents is:

```text
.zfa.json      -> what this project prefers by default
.zfa/          -> what has been planned, generated, and decided over time
```

### Canonical `.zfa/` layout

```text
.zfa/
├── plans/
├── runs/
├── blueprints/
├── decisions/
├── manifests/
└── context.json
```

During the v5 migration, some internal surfaces may still reference older storage paths. Treat the structure above as the public documentation contract going forward.

---

## `make` first, `feature` second

If you see both commands in the codebase, prefer this rule:

- Use **`zfa make`** when you want explicit control.
- Use **`zfa feature scaffold`** only when you intentionally want the feature preset wrapper.

Equivalent example:

```bash
zfa make Product --preset=feature --plan
```

```bash
zfa feature scaffold Product --plan
```

---

## AI-agent contract

For Zuraffa v5 projects:

- Generate **architecture code** with `zfa`, not by hand.
- Create entities with `zfa entity create`.
- Generate layers with `zfa make`.
- Run `zfa build` after generation.
- Handcraft only manual UI composition/layout zones and normal business implementation details that generation does not own.

### The pipeline rule

If an AI agent is asked to build a feature, it should always start by asking:

1. **Does a new entity need to exist?** → use `zfa entity create`
2. **Does the architecture skeleton need to exist or change?** → use `zfa make`
3. **Do generated annotations/build outputs need to be finalized?** → use `zfa build`

Zuraffa owns the architecture skeleton. Human or agent implementation work should narrow to the remaining business logic, datasource implementation, styling, and manual UI composition after that pipeline runs.

---

## Migration notes

If you are coming from pre-v5 guidance:

- the old one-shot generator command is gone,
- `zfa make` is now the canonical generator,
- `zfa feature` is a wrapper, not the primary public workflow,
- the domain root is fixed to `lib/src/domain`, and
- v5 public docs assume Zorphy-based entities.

See `doc/MIGRATION_GUIDE.md` for a focused migration walkthrough.

---

## Mock data & prototyping (v5.1.0)

```bash
# Generate Dart mock data
zfa mock Product

# Generate JSON mock data with fromJson-based helpers
zfa mock json Product
```

JSON mocks produce standalone JSON files under `data/mock_json/{domain}/` and Dart helpers that load them via `fromJson`. Swap JSON content for instant prototyping without code changes or regeneration.

```dart
final products = await ProductMockJson.loadProducts();
final sample = await ProductMockJson.loadSampleProduct();
```

See [`website/docs/features/mock-data.md`](website/docs/features/mock-data.md) for details.

---

## Learn more

- `CLI_GUIDE.md`
- `AGENTS.md`
- `SKILL.md`
- `website/docs/intro.md`
- `doc/MIGRATION_GUIDE.md`

Made with 🦒 and ⚡ by the Zuraffa project.
