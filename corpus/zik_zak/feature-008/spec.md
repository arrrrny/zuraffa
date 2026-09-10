**Template Version**: `zuraffa-1.0`

# Spec: 008

## Summary

The 008 feature, as the ZikZak app ships it.

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

- **FR-001**: The system MUST save a Message when the user commits the 008 form.
  traces: `MessageRepo.save`
- **FR-002**: The system MUST restore the last 008 state on cold start.
  traces: `Hive.put`, `MessageRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open 008 **Then** the saved Message list renders.
   **Type**: widget
2. **Given** an empty local cache **When** 008 loads **Then** the placeholder renders.
   **Type**: widget
3. **Given** a committed Message **When** the device restarts **Then** the value equals the last write.
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

