# Data Model: Federated Plugin Scaffold

**Feature**: specs/1601-package-plugin-scaffold | **Date**: 2026-09-13

Entities (in-memory values only — the scaffold writes files, no storage).

## PluginScaffoldRequest

| Field | Type | Default | Validation |
| -- | -- | -- | -- |
| `name` | `String` | required | `^[a-z][a-z0-9_]*$` (FR-010) |
| `platforms` | `Set<PluginPlatform>` | `{android, ios, macos}` | non-empty; known values only (FR-005) |
| `outputParent` | `String` | `'.'` | must exist |
| `description` | `String?` | `'Typed <name> plugin for the Zuraffa ecosystem: <platforms> adapters over a shared platform core.'` | stamped into every package (FR-012) |
| `repository` | `String?` | `arrrrny/<name>` | GitHub slug `owner/name` (FR-012) |
| `zuraffaPath` | `String?` | `null` (hosted `^<version>`) | must be an existing directory (FR-013) |
| `dryRun` | `bool` | `false` | writes nothing when `true` (FR-009) |

## PluginPlatform (enum)

`android`, `ios`, `macos` — each maps to an adapter package name suffix and
a topics entry.

## PluginFamilyNames

Derived from `name` (validated). Pure functions — no I/O.

| Member | Rule | Example (`zuraffa_ffi`) |
| -- | -- | -- |
| `app` | `name` as-is | `zuraffa_ffi` |
| `core` | `${name}_platform` | `zuraffa_ffi_platform` |
| `adapter(platform)` | `${name}_${platform}` | `zuraffa_ffi_android` |
| `appPascal` / `corePascal` / `adapterPascal(platform)` | snake → PascalCase | `ZuraffaFfi`, `ZuraffaFfiPlatform`, `ZuraffaFfiAndroid` |

## PluginScaffoldResult

| Field | Type | Notes |
| -- | -- | -- |
| `monorepoPath` | `String` | `<outputParent>/<name>` |
| `createdFiles` | `List<String>` | monorepo-relative paths of every file written (all reported in dry-run, none written) |
| `packages` | `List<GeneratedPackage>` | role-tagged, for reporting/tests |

## GeneratedPackage

| Field | Type | Notes |
| -- | -- | -- |
| `name` | `String` | full package name |
| `role` | `PackageRole` | `app` / `core` / `adapter` |
| `path` | `String` | monorepo-relative package dir |
| `platform` | `PluginPlatform?` | set iff `role == adapter` |

## Generated monorepo (file tree, full platform set)

```text
<name>/                                  # monorepo root
├── README.md                            # family table + develop/consume guide (FR-011)
├── PUBLISH.md                           # release workflow (FR-011)
├── LICENSE                              # MIT, family-standard holder (FR-011)
├── CHANGELOG.md                         # seeded ## 1.0.0 (FR-011)
├── .gitignore                           # Dart + tooling ignores (FR-011)
├── scripts/
│   ├── prepare_for_publish.sh           # version-align + changelog propagate + commit (FR-007)
│   ├── publish.sh                       # dry-run + publish, app → core → adapters (FR-007)
│   └── push_to_master.sh                # merge publish branch, tag, push (FR-007)
└── packages/
    ├── <name>/                          # ROLE app — depends on zuraffa only
    │   ├── pubspec.yaml                 # metadata + zuraffa ^6.x + test/lints dev deps
    │   ├── analysis_options.yaml
    │   ├── CHANGELOG.md
    │   ├── LICENSE
    │   ├── README.md
    │   ├── lib/<name>.dart              # barrel: core port + channel abstraction
    │   ├── lib/src/<name>_port.dart     # pure port: typed interface the app codes against
    │   ├── lib/src/<name>_channel.dart  # injected channel abstraction (default: none registered)
    │   ├── lib/src/<name>_exception.dart# typed error plumbing
    │   ├── lib/src/register.dart        # adapter registration hook (no-op default)
    │   └── test/<name>_smoke_test.dart  # harness: port contract over a fake channel (FR-008)
    ├── <name>_platform/                 # ROLE core — depends on app package only
    │   ├── (same metadata set)
    │   ├── lib/<name>_platform.dart
    │   ├── lib/src/platform_envelope.dart  # request/response envelope, decode, timeout policy
    │   └── test/platform_envelope_test.dart
    └── <name>_<platform>/               # ROLE adapter ×N — depends on app + core
        ├── (same metadata set)
        ├── lib/<name>_<platform>.dart
        ├── lib/src/<platform>_<name>_channel.dart  # envelope over injected channel
        ├── lib/src/register.dart                    # registers the platform impl
        └── test/<platform>_adapter_test.dart        # envelope round-trip on a fake channel
```

## Dependency graph (invariants asserted by tests — FR-004)

```text
<name> (app)      ──> zuraffa (hosted ^6.x)
<name>_platform   ──> <name> (hosted ^1.0.0)
<name>_<platform> ──> <name> ^1.0.0  +  <name>_platform ^1.0.0
(nobody depends on an adapter; core never depends on an adapter)
```

`dependency_overrides` (dev-only, stripped by pub on publish — FR-006):

- core: `<name> -> ../<name>`
- adapter: `<name> -> ../<name>`, `<name>_platform -> ../<name>_platform`
- every package when `--zuraffa-path` given: `zuraffa -> <path>`
