# Spec: Crash Reporting

**Template Version**: `zuraffa-1.0`

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| AlertRow | `id: String` | one row |

## Layer Contracts

**Domain**:
- `AlertRepo`: `list(QueryParams) -> List<AlertRow>`

## Functional Requirements

Requirements are declared as a table; variants are continuation rows.

| ID | Requirement | Variants |
| -- | -- | -- |
| FR-001 | The system MUST list Alert rows for Crash Reporting. | — |
| | variant: offline — the cached list renders. | v1 |
| | variant: empty — the placeholder renders. | v2 |
| FR-002 | The system MUST refresh the Crash Reporting list on pull. | — |

## Acceptance Scenarios

1. **Given** cached rows **When** Crash Reporting opens offline **Then** the cached list renders.
   **Type**: widget

