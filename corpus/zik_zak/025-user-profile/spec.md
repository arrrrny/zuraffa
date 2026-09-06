**Template Version**: `zuraffa-1.0`

# Spec: User Profile

## Summary

The User Profile feature, as the ZikZak app ships it.

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| SessionParams | `id: String`, `value: num` | typed params |
| SessionView | `state: SessionState` | rendered row |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |
| RestChannel | channel: http | `send(Request) -> Response` | high |

## Layer Contracts

**Domain**:
- `SessionRepo`: `save(SessionParams) -> Session`, `get(String) -> Session?`

**Presentation**:
- `SessionPresenter`: `present(SessionState) -> SessionView`

## Functional Requirements

- **FR-001**: The system MUST save a Session when the user commits the User Profile form.
  traces: `SessionRepo.save`
- **FR-002**: The system MUST restore the last User Profile state on cold start.
  traces: `Hive.put`, `SessionRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open User Profile **Then** the saved Session list renders.
   **Type**: widget
2. **Given** an empty local cache **When** User Profile loads **Then** the placeholder renders.
   **Type**: widget
3. **Given** a committed Session **When** the device restarts **Then** the value equals the last write.
   **Type**: acceptance

