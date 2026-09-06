**Template Version**: `zuraffa-1.0`

# Spec: Reactions

## Summary

The Reactions feature, as the ZikZak app ships it.

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| ReportParams | `id: String`, `value: num` | typed params |
| ReportView | `state: ReportState` | rendered row |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |
| RestChannel | channel: http | `send(Request) -> Response` | high |

## Layer Contracts

**Domain**:
- `ReportRepo`: `save(ReportParams) -> Report`, `get(String) -> Report?`

**Presentation**:
- `ReportPresenter`: `present(ReportState) -> ReportView`

## Functional Requirements

- **FR-001**: The system MUST save a Report when the user commits the Reactions form.
  traces: `ReportRepo.save`
- **FR-002**: The system MUST restore the last Reactions state on cold start.
  traces: `Hive.put`, `ReportRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open Reactions **Then** the saved Report list renders.
   **Type**: widget
2. **Given** an empty local cache **When** Reactions loads **Then** the placeholder renders.
   **Type**: widget
3. **Given** a committed Report **When** the device restarts **Then** the value equals the last write.
   **Type**: acceptance

