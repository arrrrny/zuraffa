**Template Version**: `zuraffa-1.0`

# Spec: Comment Thread

## Summary

The Comment Thread feature, as the ZikZak app ships it.

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

- **FR-001**: The system MUST save a Ticket when the user commits the Comment Thread form.
  traces: `TicketRepo.save`
- **FR-002**: The system MUST restore the last Comment Thread state on cold start.
  traces: `Hive.put`, `TicketRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open Comment Thread **Then** the saved Ticket list renders.
   **Type**: widget
2. **Given** an empty local cache **When** Comment Thread loads **Then** the placeholder renders.
   **Type**: widget
3. **Given** a committed Ticket **When** the device restarts **Then** the value equals the last write.
   **Type**: acceptance

