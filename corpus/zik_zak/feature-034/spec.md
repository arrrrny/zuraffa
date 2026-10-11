**Template Version**: `zuraffa-1.0`

# Spec: 034

## Summary

The 034 feature, as the ZikZak app ships it.

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| CouponParams | `id: String`, `value: num` | typed params |
| CouponView | `state: CouponState` | rendered row |

## External Dependencies & Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |
| RestChannel | channel: http | `send(Request) -> Response` | high |

## Layer Contracts

**Domain**:
- `CouponRepo`: `save(CouponParams) -> Coupon`, `get(String) -> Coupon?`

**Presentation**:
- `CouponPresenter`: `present(CouponState) -> CouponView`

## Functional Requirements

- **FR-001**: The system MUST save a Coupon when the user commits the 034 form.
- **FR-002**: The system MUST restore the last 034 state on cold start.

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open 034 **Then** the saved Coupon list renders.
2. **Given** an empty local cache **When** 034 loads **Then** the placeholder renders.
3. **Given** a committed Coupon **When** the device restarts **Then** the value equals the last write.

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

