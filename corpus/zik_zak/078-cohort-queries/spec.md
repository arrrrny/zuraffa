# Spec: Cohort Queries

**Template Version**: `zuraffa-1.0`

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| BookmarkRow | `id: String` | one row |

## Layer Contracts

**Domain**:
- `BookmarkRepo`: `list(QueryParams) -> List<BookmarkRow>`

## Functional Requirements

Requirements are declared as a table; variants are continuation rows.

| ID | Requirement | Variants |
| -- | -- | -- |
| FR-001 | The system MUST list Bookmark rows for Cohort Queries. | — |
| | variant: offline — the cached list renders. | v1 |
| | variant: empty — the placeholder renders. | v2 |
| FR-002 | The system MUST refresh the Cohort Queries list on pull. | — |

## Acceptance Scenarios

1. **Given** cached rows **When** Cohort Queries opens offline **Then** the cached list renders.
   **Type**: widget

