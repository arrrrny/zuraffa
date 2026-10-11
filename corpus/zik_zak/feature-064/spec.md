# Spec: 064

**Template Version**: `zuraffa-1.0`

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| OrderMeta | `label: String` | display name |

## External Dependencies &amp; Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |

## Layer Contracts

**Domain**:
- `OrderRepo`: `get(String) -> Order?`

## Functional Requirements

- **FR-001**: The system MUST escape the &quot;quoted&quot; label.
  traces: `OrderRepo`
- **FR-002**: The system MUST reject values with &lt;script&gt; content.
  traces: `OrderRepo`

## Acceptance Scenarios

1. **Given** a &quot;quoted&quot; label **When** 064 renders **Then** the label renders escaped.
   **Type**: widget

