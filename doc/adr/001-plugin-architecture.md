# 001 - Plugin Architecture

## Status

Accepted

## Context

Zuraffa generates multiple layers (domain, data, presentation, DI, routing). A monolithic generator made it difficult to extend, test, and evolve each layer independently. The CLI also needs predictable lifecycle hooks for validation and error handling.

## Decision

Adopt a plugin architecture with a small core contract:

- `ZuraffaPlugin` defines lifecycle hooks and identification
- `FileGeneratorPlugin` returns `GeneratedFile` results
- `PluginRegistry` coordinates lifecycle ordering and execution

## Consequences

- Individual generators are isolated and testable
- New features can be added as plugins without modifying core
- Lifecycle hooks provide consistent validation and error handling

## Alternatives Considered

- Single monolithic generator with conditional branches
- DI-based feature flags without explicit plugin boundaries

## References

- `lib/src/core/plugin_system/plugin_interface.dart`
- `lib/src/core/plugin_system/plugin_registry.dart`
- `lib/src/core/plugin_system/plugin_lifecycle.dart`
