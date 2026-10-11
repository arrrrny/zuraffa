**Template Version**: `zuraffa-1.0`

# Spec: 016

## Summary

The 016 feature, as the ZikZak app ships it.

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

- **FR-001**: The system MUST save a Order when the user commits the 016 form.
  traces: `OrderRepo.save`
- **FR-002**: The system MUST restore the last 016 state on cold start.
  traces: `Hive.put`, `OrderRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open 016 **Then** the saved Order list renders.
   **Type**: widget
2. **Given** an empty local cache **When** 016 loads **Then** the placeholder renders.
   **Type**: widget
3. **Given** a committed Order **When** the device restarts **Then** the value equals the last write.
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

