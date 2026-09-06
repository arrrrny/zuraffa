**Template Version**: `zuraffa-1.0`

# Spec: Chat List

## Summary

The Chat List feature, as the ZikZak app ships it.

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

- **FR-001**: The system MUST save a Alert when the user commits the Chat List form.
- **FR-002**: The system MUST restore the last Chat List state on cold start.

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open Chat List **Then** the saved Alert list renders.
2. **Given** an empty local cache **When** Chat List loads **Then** the placeholder renders.
3. **Given** a committed Alert **When** the device restarts **Then** the value equals the last write.

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

