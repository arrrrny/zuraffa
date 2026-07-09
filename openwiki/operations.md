# Operations

Common operational tasks for working with Zuraffa projects: configuration, debugging, CI, caching, and migration.

## Project Configuration

### `.zfa.json`

Zuraffa uses a `.zfa.json` file at the project root for persistent defaults. Initialize it with:

```bash
zfa config init
```

The config file supports:

| Key | Purpose |
|---|---|
| `entityFirst` | Require entity existence before generation (default: `true`) |
| `disabledPlugins` | List of plugin IDs to skip during generation |
| `customPresets` | Define additional named presets (map of name → plugin ID list) |
| `customAliases` | Define additional aliases (map of alias → plugin ID list) |
| `defaultPreset` | Preset applied when none is specified |
| `defaultMethods` | Default set of CRUD methods |
| `domainRoot` | Custom domain output root (default: `lib/src/domain`) |
| `outputDir` | Custom overall output directory (default: `lib/src`) |

**Source file**: `lib/src/config/zfa_config.dart` (~400 lines)

### Plugin Configuration

Individual plugins can be enabled/disabled:

```bash
zfa plugin list              # List all plugins with status
zfa plugin enable <id>       # Enable a plugin
zfa plugin disable <id>      # Disable a plugin
```

**Source file**: `lib/src/commands/plugin_command.dart`

---

## Environment Health

The `doctor` command inspects tooling and environment:

```bash
zfa doctor              # Quick diagnostic
zfa doctor --full       # Comprehensive check
```

**What it checks**:
- Dart/Flutter SDK versions
- `build_runner` availability
- Zorphy annotation setup
- Project structure conventions
- `.zfa.json` validity

**Source file**: `lib/src/commands/doctor_command.dart`

---

## Debugging

### Plan Preview

Always preview what `zfa make` will generate before writing files:

```bash
zfa make Product --preset=crud --plan
zfa make Product --preset=crud --explain   # More detailed explanation
```

### Dry Run

```bash
zfa make Product --preset=crud --dry-run
```

### Debug Artifacts

The `DebugArtifactSaver` (`lib/src/core/debug/artifact_saver.dart`) saves generation diagnostics to `.zfa_debug/<timestamp>/` when enabled — including config snapshots, generation results, and error details.

### Revert

Each generation run persists a plan to the `PlanStore` (`lib/src/core/plugin_system/plan_store.dart`). Undo the last generation:

```bash
zfa make Product --revert
```

This deletes created files and restores previous content using the saved `EffectReport`.

---

## CI/CD

### GitHub Actions

The repository includes a CI pipeline (`.github/workflows/ci.yaml`) with 4 parallel jobs:

1. **analyze** — `flutter analyze`
2. **format** — `dart format --set-exit-if-changed .`
3. **build_example** — `flutter build appbundle` (example project compiles)
4. **test** — `flutter test --coverage` + Codecov upload

### Testing in CI

Integration tests are tagged and excluded from the default test runner via `dart_test.yaml`:

```yaml
exclude_tags: integration
```

Run integration tests explicitly:

```bash
flutter test test/integration/
```

---

## Caching

Generated caching layer supports three cache policies:

| Policy | Duration | Storage | CLI Flag |
|---|---|---|---|
| `DailyCachePolicy` | 24 hours | Persistent (SharedPrefs/Hive) | `--cache-policy=daily` |
| `AppRestartCachePolicy` | App session | In-memory | `--cache-policy=restart` |
| `TtlCachePolicy` | Configurable TTL | Persistent | `--cache-policy=ttl` |

Generate with caching:

```bash
zfa make Product --methods=get,getList --cache --cache-policy=daily --cache-storage=hive
```

**Detailed guide**: [CACHING.md](../CACHING.md)

---

## Offline-First Sync

The sync plugin generates metadata stores and strategy factories for offline-first data:

```bash
zfa make Product --methods=get,getList --sync
```

**Key types** (`lib/src/core/`):

| Type | File | Values |
|---|---|---|
| `SyncStatus` | `sync_status.dart` | pending, syncing, synced, failed, conflicted |
| `SyncOperation` | `sync_operation.dart` | create, update, delete |
| `SyncDirection` | `sync_direction.dart` | push, pull, bidirectional |
| `SyncStrategy` | `sync_strategy.dart` | PushOnlySyncStrategy, BidirectionalSyncStrategy |
| `SyncConfig` | `sync_config.dart` | batchSize, maxRetries, backoff, autoSync |

---

## Migration: v4 → v5

### Key Changes

| v4 (Legacy) | v5 (Current) |
|---|---|
| `zfa generate` | `zfa make` |
| `--with-view`, `--with-state` | `--preset=crud`, `--with=vpc`, `--state` |
| Implicit plan | Explicit `GenerationPlan` with `--plan`/`--explain` |
| No transactions | Atomic transactional file writes |
| No project memory | `.zfa/` with plans, runs, blueprints, decisions |
| Basic DI | Full per-usecase DI registration with index files |

### Migration Steps

1. Replace `zfa generate` calls with `zfa make --preset=crud`
2. Replace `--with-view` with `--with=vpc` and `--state`
3. Remove hand-written entity creation; use `zfa entity create`
4. Replace `build_runner` calls with `zfa build`
5. Review generated DI structure (`lib/src/di/`) for any custom registrations

**Full reference**: [docs/v4_vs_v5_comparison.md](../docs/v4_vs_v5_comparison.md)

---

## Retry Policies

The `ExponentialBackoffRetryPolicy` (`lib/src/core/retry_policies.dart`) provides configurable retry for failure reporters and sync operations:

| Parameter | Default | Description |
|---|---|---|
| `multiplier` | 1.5 | Delay multiplier between retries |
| `maxInterval` | 30 seconds | Maximum delay between retries |
| `maxRetries` | 5 | Maximum retry attempts |
| `maxElapsed` | 5 minutes | Total time budget |

---

## Source Map

```
lib/src/
├── config/zfa_config.dart           # Project config management
├── commands/
│   ├── doctor_command.dart          # Environment health check
│   ├── plugin_command.dart          # Plugin enable/disable
│   └── config_command.dart          # .zfa.json management
├── core/
│   ├── cache_policies.dart          # Daily, AppRestart, TTL cache policies
│   ├── sync_config.dart             # Sync configuration
│   ├── sync_strategy.dart           # Push-only and bidirectional sync
│   ├── retry_policies.dart          # Exponential backoff retry
│   ├── debug/artifact_saver.dart    # Debugging diagnostics
│   └── plugin_system/plan_store.dart # Persisted plan for revert
doc/
├── CACHING.md                       # Caching deep-dive
├── V5_ACTION_PLAN.md                # v5 migration plan
docs/v4_vs_v5_comparison.md          # Migration guide
scripts/                             # Build/CI helper scripts
```
