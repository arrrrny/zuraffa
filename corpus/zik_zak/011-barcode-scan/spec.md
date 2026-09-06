**Template Version**: `zuraffa-1.0`

# Spec: Barcode Scan

## Summary

The Barcode Scan feature, as the ZikZak app ships it.

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| TicketParams | `id: String`, `value: num` | typed params |
| TicketView | `state: TicketState` | rendered row |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |
| RestChannel | channel: http | `send(Request) -> Response` | high |

## Layer Contracts

**Domain**:
- `TicketRepo`: `save(TicketParams) -> Ticket`, `get(String) -> Ticket?`

**Presentation**:
- `TicketPresenter`: `present(TicketState) -> TicketView`

## Functional Requirements

- **FR-001**: The system MUST save a Ticket when the user commits the Barcode Scan form.
  traces: `TicketRepo.save`
- **FR-002**: The system MUST restore the last Barcode Scan state on cold start.
  traces: `Hive.put`, `TicketRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open Barcode Scan **Then** the saved Ticket list renders.
   **Type**: widget
2. **Given** an empty local cache **When** Barcode Scan loads **Then** the placeholder renders.
   **Type**: widget
3. **Given** a committed Ticket **When** the device restarts **Then** the value equals the last write.
   **Type**: acceptance

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [U1, U2]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [A1, A2]
    flutter_allowed: true
  - lane: BOTH
    behaviors: [A3]
    flutter_allowed: conditionally
```

