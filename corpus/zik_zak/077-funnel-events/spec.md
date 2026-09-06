# Spec: Funnel Events

**Template Version**: `zuraffa-1.0`

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| ReceiptRow | `id: String` | one row |

## Layer Contracts

**Domain**:
- `ReceiptRepo`: `list(QueryParams) -> List<ReceiptRow>`

## Functional Requirements

Requirements are declared as a table; variants are continuation rows.

| ID | Requirement | Variants |
| -- | -- | -- |
| FR-001 | The system MUST list Receipt rows for Funnel Events. | — |
| | variant: offline — the cached list renders. | v1 |
| | variant: empty — the placeholder renders. | v2 |
| FR-002 | The system MUST refresh the Funnel Events list on pull. | — |

## Acceptance Scenarios

1. **Given** cached rows **When** Funnel Events opens offline **Then** the cached list renders.
   **Type**: widget

