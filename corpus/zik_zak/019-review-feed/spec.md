**Template Version**: `zuraffa-1.0`

# Spec: Review Feed

## Summary

The Review Feed feature, as the ZikZak app ships it.

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| AlertParams | `id: String`, `value: num` | typed params |
| AlertView | `state: AlertState` | rendered row |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |
| RestChannel | channel: http | `send(Request) -> Response` | high |

## Layer Contracts

**Domain**:
- `AlertRepo`: `save(AlertParams) -> Alert`, `get(String) -> Alert?`

**Presentation**:
- `AlertPresenter`: `present(AlertState) -> AlertView`

## Functional Requirements

- **FR-001**: The system MUST save a Alert when the user commits the Review Feed form.
  traces: `AlertRepo.save`
- **FR-002**: The system MUST restore the last Review Feed state on cold start.
  traces: `Hive.put`, `AlertRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open Review Feed **Then** the saved Alert list renders.
   **Type**: widget
2. **Given** an empty local cache **When** Review Feed loads **Then** the placeholder renders.
   **Type**: widget
3. **Given** a committed Alert **When** the device restarts **Then** the value equals the last write.
   **Type**: acceptance

