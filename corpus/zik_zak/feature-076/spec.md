# Spec: 076

**Template Version**: `zuraffa-1.0`

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| OrderRow | `id: String` | one row |

## Layer Contracts

**Domain**:
- `OrderRepo`: `list(QueryParams) -> List<OrderRow>`

## Functional Requirements

Requirements are declared as a table; variants are continuation rows.

| ID | Requirement | Variants |
| -- | -- | -- |
| FR-001 | The system MUST list Order rows for 076. | — |
  traces: `OrderRepo`
| | variant: offline — the cached list renders. | v1 |
| | variant: empty — the placeholder renders. | v2 |
| FR-002 | The system MUST refresh the 076 list on pull. | — |
  traces: `OrderRepo`

## Acceptance Scenarios

1. **Given** cached rows **When** 076 opens offline **Then** the cached list renders.
   **Type**: widget

