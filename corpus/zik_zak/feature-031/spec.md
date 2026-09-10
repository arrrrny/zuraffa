**Template Version**: `zuraffa-1.0`

# Spec: 031

## Summary

The 031 feature, as the ZikZak app ships it.

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

- **FR-001**: The system MUST save a Alert when the user commits the 031 form.
- **FR-002**: The system MUST restore the last 031 state on cold start.

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open 031 **Then** the saved Alert list renders.
2. **Given** an empty local cache **When** 031 loads **Then** the placeholder renders.
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

