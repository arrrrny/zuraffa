**Template Version**: `zuraffa-1.0`

# Spec: 023

## Summary

The 023 feature, as the ZikZak app ships it.

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

- **FR-001**: The system MUST save a Ticket when the user commits the 023 form.
  traces: `TicketRepo.save`
- **FR-002**: The system MUST restore the last 023 state on cold start.
  traces: `Hive.put`, `TicketRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open 023 **Then** the saved Ticket list renders.
   **Type**: widget
2. **Given** an empty local cache **When** 023 loads **Then** the placeholder renders.
   **Type**: widget
3. **Given** a committed Ticket **When** the device restarts **Then** the value equals the last write.
   **Type**: acceptance

