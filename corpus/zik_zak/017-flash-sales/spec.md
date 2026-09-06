**Template Version**: `zuraffa-1.0`

# Spec: Flash Sales

## Summary

The Flash Sales feature, as the ZikZak app ships it.

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| ReceiptParams | `id: String`, `value: num` | typed params |
| ReceiptView | `state: ReceiptState` | rendered row |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |
| RestChannel | channel: http | `send(Request) -> Response` | high |

## Layer Contracts

**Domain**:
- `ReceiptRepo`: `save(ReceiptParams) -> Receipt`, `get(String) -> Receipt?`

**Presentation**:
- `ReceiptPresenter`: `present(ReceiptState) -> ReceiptView`

## Functional Requirements

- **FR-001**: The system MUST save a Receipt when the user commits the Flash Sales form.
  traces: `ReceiptRepo.save`
- **FR-002**: The system MUST restore the last Flash Sales state on cold start.
  traces: `Hive.put`, `ReceiptRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open Flash Sales **Then** the saved Receipt list renders.
   **Type**: widget
2. **Given** an empty local cache **When** Flash Sales loads **Then** the placeholder renders.
   **Type**: widget
3. **Given** a committed Receipt **When** the device restarts **Then** the value equals the last write.
   **Type**: acceptance

