# 005 - Zorphy for Entities and Typed Updates

## Status

Accepted

## Context

Zuraffa needs a consistent entity model with typed fields, filtering, and update semantics. The generator also needs to support typed patch updates in addition to partial maps.

## Decision

Adopt Zorphy as the default entity and patch system. Zuraffa integrates with Zorphy for:

- Entity creation via CLI
- Typed patch updates using `Patch` classes
- Typed filters and query parameters

Zorphy remains configurable via CLI and config defaults.

## Consequences

- Stronger typing across entities and updates
- Shared conventions for query filters and patches
- Requires zorphy_annotation for entity generation

## Alternatives Considered

- Freezed for data classes
- Manual entity authoring with custom build_runner

## References

- `lib/src/commands/entity_command.dart`
- `lib/src/config/zfa_config.dart`
- `lib/src/core/list_query_params.dart`
