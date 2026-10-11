The `.zfa.json` file and `.zfa/` directory form Zuraffa's **project memory surface** — a persistent, machine-readable record of every generation run, configuration decision, and proof artifact. Together they enable reproducible builds, drift detection, and agent continuity across sessions.

## Architecture Overview

```
Project Root
├── .zfa.json              # Static configuration (plugin defaults, UI prefs, entity rules)
└── .zfa/
    └── receipts/          # Append-only proof records (one JSON per generation run)
        ├── 2026-09-05T09-50-10Z-tdd_gen-A1.json
        ├── 2026-09-16T01-37-55Z-tdd_make-A8.json
        └── ...
```

The configuration layer (`.zfa.json`) declares **what** the project generates by default. The receipts layer (`.zfa/receipts/`) proves **that** and **from what** each artifact was generated. The two are coupled: `zfa proof check` re-derives every SHA-256 digest in the receipts against the current filesystem and fails on any mismatch.

Sources: [zfa_config.dart](lib/src/config/zfa_config.dart#L1-L330), [receipt_store.dart](lib/src/core/project/receipt_store.dart#L1-L330)

## `.zfa.json` — Configuration Schema

The configuration file is a JSON document with five top-level sections. The `ZfaConfig` class in `lib/src/config/zfa_config.dart` is the single parser and serializer; all write paths (`config init`, `config set`, `make`) round-trip through it.

| Section | Purpose | Key fields |
|---------|---------|------------|
| `mocking` | Canonical mock library signature | `library`, `import`, `marker`, `mockSources` |
| `plugins` | Default plugin enablement | `defaults` (map of plugin id → bool), `disabled` (list) |
| `planning` | Presets and aliases | `presets`, `aliases` (map of name → list of plugin ids) |
| `ui` | Adaptive layout preferences | `adaptiveLayouts`, `platformShells`, `layoutTargets`, `adaptivePreset` |
| `entity` | Entity-generation behavior | `entityFirst`, `jsonByDefault`, `compareByDefault`, `filterByDefault` |
| *top-level* | Build/format flags | `buildByDefault`, `formatByDefault` |
| *top-level (opt)* | Feature flags (raw) | `features`, `flavors` — preserved verbatim by `ZfaConfig` |
| *top-level (opt)* | TDD widget shell (raw) | `tdd` — carries `widgetShell` and `i18nExpansion` |

Sources: [todo_tdd/.zfa.json](examples/todo_tdd/.zfa.json#L1-L64), [zfa_config.dart](lib/src/config/zfa_config.dart#L330-L400)

### Plugin Defaults — The Clean-Architecture Tier

Issue #1496 established a two-tier model. The **default tier** (always-on after `zfa config init`) enables the clean-architecture stack so a bare `zfa make Product` scaffolds a runnable slice:

| Plugin id | Default | Purpose |
|-----------|---------|---------|
| `repository` | true | Repository interface + implementation |
| `provider` | true | State management provider |
| `usecase` | true | Use case (interactor) |
| `presenter` | true | Presenter (MVVM) |
| `controller` | true | Controller (MVC) |
| `test` | true | Unit/integration test generation |
| `mock` | true | Mock data source / provider |
| `di` | true | Dependency injection wiring |
| `datasource` | true | Data source interface + impl |
| `service` | false | External service integration |
| `route` | true | Routing table |
| `cache` | true | Cache adapter |
| `method_append` | true | Method append capability |
| `view` | false | UI view layer |
| `feature` | false | Feature flag wiring |
| `state` | false | State management extras |
| `observer` | false | Observer pattern |
| `gym` | false | Gym/exercise scaffolding |
| `sqlite` | false | SQLite storage |
| `gql` / `graphql` | false | GraphQL client |
| `skin` | false | Skin contract |
| `xray` | false | XRay diagnostic overlay |
| `agent` | false | Agent plugin (dormant by default) |

The **opt-in tier** stays false and is enabled per project via `.zfa.json`, `--with=<plugin>`, or a preset.

Sources: [zfa_config.dart](lib/src/config/zfa_config.dart#L28-L60)

### Minimal Mode

`zfa config init --minimal` writes every plugin default as `false` — the pre-#1496 behavior — for teams that opt every default out and select plugins per command via `--preset=crud` or `--with=<plugin>`.

Sources: [config_command.dart](lib/src/commands/config_command.dart#L58-L85)

## Configuration CLI

The `zfa config` command exposes four subcommands:

| Subcommand | Behavior |
|------------|----------|
| `init [--minimal] [root]` | Creates `.zfa.json` with defaults; warns if an all-false config already exists |
| `show` / `get [root]` | Prints the resolved configuration as pretty JSON |
| `set <key> <value>` | Updates one key and persists; refuses to overwrite unparseable files |
| `help` | Prints usage |

Configuration keys fall into two families: top-level booleans (`buildByDefault`, `formatByDefault`, `filterByDefault`, `entityFirst`) and plugin-default keys derived by `ZfaConfig.pluginIdForConfigKey()` (e.g. `diByDefault` → `di`, `repositoryByDefault` → `repository`, `appendByDefault` → `method_append`).

Sources: [config_command.dart](lib/src/commands/config_command.dart#L10-L210)

## `.zfa/receipts/` — Proof Records

The receipts directory is the **project memory core**. Every generation run writes one JSON document with schema `proof.v1`. The directory currently holds 109 receipts spanning `tdd gen`, `tdd verify-red`, `tdd make`, and `tdd plan` commands.

### Receipt Naming

Two naming schemes coexist:

1. **Timestamped** (default): `{ISO8601stamp}-{command}-{target}.json` — e.g. `2026-09-16T01-37-55.097187Z-tdd_make-A8.json`. Colons are replaced with `-` for Windows portability. Append-only history.

2. **Stable** (per-entity/per-plugin): `{name}.json` — e.g. `mock-<entity>.json`, `provider-<entity>.json`, `routes-<entity>.json`, `state-<entity>.json`. Regeneration supersedes the previous document in place (last-write-wins).

Sources: [receipt_store.dart](lib/src/core/project/receipt_store.dart#L180-L260)

### Receipt Schema (`proof.v1`)

| Field | Type | Description |
|-------|------|-------------|
| `schema` | string | Always `"proof.v1"` |
| `command` | string | The generation command (e.g. `tdd gen`, `tdd make`) |
| `target` | string | What the run was about (usually an entity name or behavior id) |
| `repro` | string | One-line command a human/agent can paste to reproduce |
| `at` | string (ISO8601) | UTC timestamp of the run |
| `generator_version` | string | Template/generator version that produced the artifacts |
| `input` | object | Input context (flags, fields, plugin ids, feature name) |
| `spec` | object (opt) | The spec the run consumed: `{path, sha256, snapshot?}` |
| `files` | array | Each artifact: `{path, action, sha256, bytes, snapshot?}` |
| `plugin` | string (opt) | Plugin id for standalone capability receipts |
| `capability` | string (opt) | Capability name (`create`, `adapter`, `enable`, ...) |
| `entity` | string (opt) | Entity the capability operated on |
| `methodset` | array (opt) | Method list the invocation wired |
| `hash` | string (opt) | SHA-256 run digest binding entity + methodset + file tuples |
| `receipt_version` | int | Machine schema version (currently 1) |
| `min_core_version` | string (opt) | Oldest core the artifacts are guaranteed to compile against |
| `generated_against_core` | string (opt) | Core version actually resolved and generated against |

Sources: [receipt_store.dart](lib/src/core/project/receipt_store.dart#L30-L180), [sample receipt](.zfa/receipts/2026-09-16T01-37-55.097187Z-tdd_make-A8.json#L1-L10)

### Snapshot Strategy

Artifacts at or below 16 KB keep a full content `snapshot` in their receipt entry, enabling precise line-level drift diffs. Larger artifacts verify by digest only.

Sources: [receipt_store.dart](lib/src/core/project/receipt_store.dart#L24-L26)

### Corruption Handling

`ReceiptStore.loadAll()` skips corrupted documents rather than failing — one broken receipt must not erase the provenance of every healthy artifact. Records are sorted oldest-first with ties broken by filename for deterministic latest-wins indexing.

Sources: [receipt_store.dart](lib/src/core/project/receipt_store.dart#L280-L310)

## Configuration ↔ Receipts Coupling

The configuration declares intent; the receipts record provenance. The coupling point is `zfa proof check`, which:

1. Loads every receipt via `ReceiptStore.loadAll()`
2. For each `(path, action, sha256)` tuple, re-derives the SHA-256 from the current filesystem
3. Fails on any artifact whose digest no longer matches, naming the exact delta
4. Cross-checks the `spec.sha256` binding — if the spec changed, the artifact is stale

This means changing `.zfa.json` plugin defaults does **not** invalidate existing receipts (configuration is not an artifact), but changing an entity spec **does** — the spec digest is bound at generation time.

Sources: [receipt_store.dart](lib/src/core/project/receipt_store.dart#L310-L330), [zfa_config.dart](lib/src/config/zfa_config.dart#L1-L330)

## Project Memory in Practice

A typical generation cycle produces three layers of project memory:

1. **Configuration** (`.zfa.json`) — what the project is configured to do
2. **Receipts** (`.zfa/receipts/`) — what was actually generated, from what inputs, with what digests
3. **Artifacts** (the generated Dart files) — the deliverables themselves

AI agents and human developers read `.zfa.json` to understand project intent, consult `.zfa/receipts/` to trace where an artifact came from and whether it is stale, and use `zfa proof check` to verify the whole chain before merging.

Sources: [ZFA_MEMORY_GUIDE.md](doc/ZFA_MEMORY_GUIDE.md#L1-L100), [receipt_store.dart](lib/src/core/project/receipt_store.dart#L1-L330)

## Next Steps

- **[CLI Commands & Subcommands](6-cli-commands-and-subcommands)** — explore the `config`, `proof`, and `make` commands that write and read this memory surface
- **[Code Generation Engine & Proof Receipts](9-code-generation-engine-and-proof-receipts)** — understand how the engine produces receipts and how the proof checker validates them
- **[TDD Cycle & Spec-Driven Development](13-tdd-cycle-and-spec-driven-development)** — see how the TDD workflow writes `tdd gen` / `tdd make` receipts into `.zfa/receipts/`
- **[Project Architecture & Layout](3-project-architecture-and-layout)** — understand where `.zfa.json` and `.zfa/` sit relative to `.specify/`, `specs/`, and the generation output tree