**Template Version**: `zuraffa-1.0`

# Spec: Block User

## Summary

The Block User feature, as the ZikZak app ships it.

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| ReceiptParams | `id: String`, `value: num` | typed params |
| ReceiptView | `state: ReceiptState` | rendered row |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |
| RestChannel | channel: http | `send(Request) -> Response` | high |

## Layer Contracts

**Domain**:
- `ReceiptRepo`: `save(ReceiptParams) -> Receipt`, `get(String) -> Receipt?`

**Presentation**:
- `ReceiptPresenter`: `present(ReceiptState) -> ReceiptView`

## Functional Requirements

- **FR-001**: The system MUST save a Receipt when the user commits the Block User form.
- **FR-002**: The system MUST restore the last Block User state on cold start.

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open Block User **Then** the saved Receipt list renders.
2. **Given** an empty local cache **When** Block User loads **Then** the placeholder renders.
3. **Given** a committed Receipt **When** the device restarts **Then** the value equals the last write.

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

