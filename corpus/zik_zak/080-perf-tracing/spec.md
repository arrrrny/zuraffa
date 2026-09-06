# Spec: Perf Tracing

**Template Version**: `zuraffa-1.0`

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| MessageRow | `id: String` | one row |

## Layer Contracts

**Domain**:
- `MessageRepo`: `list(QueryParams) -> List<MessageRow>`

## Functional Requirements

Requirements are declared as a table; variants are continuation rows.

| ID | Requirement | Variants |
| -- | -- | -- |
| FR-001 | The system MUST list Message rows for Perf Tracing. | — |
| | variant: offline — the cached list renders. | v1 |
| | variant: empty — the placeholder renders. | v2 |
| FR-002 | The system MUST refresh the Perf Tracing list on pull. | — |

## Acceptance Scenarios

1. **Given** cached rows **When** Perf Tracing opens offline **Then** the cached list renders.
   **Type**: widget

