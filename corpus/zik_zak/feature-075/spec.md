# Spec: 075

**Template Version**: `zuraffa-1.0`

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| WalletRow | `id: String` | one row |

## Layer Contracts

**Domain**:
- `WalletRepo`: `list(QueryParams) -> List<WalletRow>`

## Functional Requirements

Requirements are declared as a table; variants are continuation rows.

| ID | Requirement | Variants |
| -- | -- | -- |
| FR-001 | The system MUST list Wallet rows for 075. | — |
| | variant: offline — the cached list renders. | v1 |
| | variant: empty — the placeholder renders. | v2 |
| FR-002 | The system MUST refresh the 075 list on pull. | — |

## Acceptance Scenarios

1. **Given** cached rows **When** 075 opens offline **Then** the cached list renders.
   **Type**: widget

