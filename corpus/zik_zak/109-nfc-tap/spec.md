**Template Version**: `zuraffa-99.0`

**Template Version**: `zuraffa-1.0`

# Spec: Nfc Tap

## Summary

The Nfc Tap feature, as the ZikZak app ships it.

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

- **FR-001**: The system MUST save a Session when the user commits the Nfc Tap form.
  traces: `SessionRepo.save`
- **FR-002**: The system MUST restore the last Nfc Tap state on cold start.
  traces: `Hive.put`, `SessionRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open Nfc Tap **Then** the saved Session list renders.
2. **Given** an empty local cache **When** Nfc Tap loads **Then** the placeholder renders.
3. **Given** a committed Session **When** the device restarts **Then** the value equals the last write.

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

