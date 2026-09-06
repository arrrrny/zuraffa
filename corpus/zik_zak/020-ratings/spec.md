**Template Version**: `zuraffa-1.0`

# Spec: Ratings

## Summary

The Ratings feature, as the ZikZak app ships it.

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| MessageParams | `id: String`, `value: num` | typed params |
| MessageView | `state: MessageState` | rendered row |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |
| RestChannel | channel: http | `send(Request) -> Response` | high |

## Layer Contracts

**Domain**:
- `MessageRepo`: `save(MessageParams) -> Message`, `get(String) -> Message?`

**Presentation**:
- `MessagePresenter`: `present(MessageState) -> MessageView`

## Functional Requirements

- **FR-001**: The system MUST save a Message when the user commits the Ratings form.
  traces: `MessageRepo.save`
- **FR-002**: The system MUST restore the last Ratings state on cold start.
  traces: `Hive.put`, `MessageRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open Ratings **Then** the saved Message list renders.
   **Type**: widget
2. **Given** an empty local cache **When** Ratings loads **Then** the placeholder renders.
   **Type**: widget
3. **Given** a committed Message **When** the device restarts **Then** the value equals the last write.
   **Type**: acceptance

