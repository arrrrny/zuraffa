# Spec: 082

**Template Version**: `zuraffa-1.0`

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| CouponRow | `id: String` | one row |

## Layer Contracts

**Domain**:
- `CouponRepo`: `list(QueryParams) -> List<CouponRow>`

## Functional Requirements

Requirements are declared as a table; variants are continuation rows.

| ID | Requirement | Variants |
| -- | -- | -- |
| FR-001 | The system MUST list Coupon rows for 082. | — |
  traces: `CouponRepo`
| | variant: offline — the cached list renders. | v1 |
| | variant: empty — the placeholder renders. | v2 |
| FR-002 | The system MUST refresh the 082 list on pull. | — |
  traces: `CouponRepo`

## Acceptance Scenarios

1. **Given** cached rows **When** 082 opens offline **Then** the cached list renders.
   **Type**: widget

