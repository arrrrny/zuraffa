**Template Version**: `zuraffa-1.0`

# Spec: 040

## Summary

The 040 feature, as the ZikZak app ships it.

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| OrderParams | `id: String`, `value: num` | typed params |
| OrderView | `state: OrderState` | rendered row |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |
| RestChannel | channel: http | `send(Request) -> Response` | high |

## Layer Contracts

**Domain**:
- `OrderRepo`: `save(OrderParams) -> Order`, `get(String) -> Order?`

**Presentation**:
- `OrderPresenter`: `present(OrderState) -> OrderView`

## Functional Requirements

- **FR-001**: The system MUST save a Order when the user commits the 040 form.
- **FR-002**: The system MUST restore the last 040 state on cold start.

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open 040 **Then** the saved Order list renders.
2. **Given** an empty local cache **When** 040 loads **Then** the placeholder renders.
3. **Given** a committed Order **When** the device restarts **Then** the value equals the last write.

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

