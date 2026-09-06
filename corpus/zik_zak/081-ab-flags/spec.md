# Spec: Ab Flags

**Template Version**: `zuraffa-1.0`

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| NotificationRow | `id: String` | one row |

## Layer Contracts

**Domain**:
- `NotificationRepo`: `list(QueryParams) -> List<NotificationRow>`

## Functional Requirements

Requirements are declared as a table; variants are continuation rows.

| ID | Requirement | Variants |
| -- | -- | -- |
| FR-001 | The system MUST list Notification rows for Ab Flags. | — |
| | variant: offline — the cached list renders. | v1 |
| | variant: empty — the placeholder renders. | v2 |
| FR-002 | The system MUST refresh the Ab Flags list on pull. | — |

## Acceptance Scenarios

1. **Given** cached rows **When** Ab Flags opens offline **Then** the cached list renders.
   **Type**: widget

