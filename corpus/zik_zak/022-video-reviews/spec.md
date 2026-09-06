**Template Version**: `zuraffa-1.0`

# Spec: Video Reviews

## Summary

The Video Reviews feature, as the ZikZak app ships it.

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

- **FR-001**: The system MUST save a Coupon when the user commits the Video Reviews form.
  traces: `CouponRepo.save`
- **FR-002**: The system MUST restore the last Video Reviews state on cold start.
  traces: `Hive.put`, `CouponRepo.get`

## Acceptance Scenarios

1. **Given** a signed-in user **When** they open Video Reviews **Then** the saved Coupon list renders.
   **Type**: widget
2. **Given** an empty local cache **When** Video Reviews loads **Then** the placeholder renders.
   **Type**: widget
3. **Given** a committed Coupon **When** the device restarts **Then** the value equals the last write.
   **Type**: acceptance

