# Spec: 062

**Template Version**: `zuraffa-1.0`

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| ProfileMeta | `label: String` | display name |

## External Dependencies &amp; Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |

## Layer Contracts

**Domain**:
- `ProfileRepo`: `get(String) -> Profile?`

## Functional Requirements

- **FR-001**: The system MUST escape the &quot;quoted&quot; label.
  traces: `ProfileRepo`
- **FR-002**: The system MUST reject values with &lt;script&gt; content.
  traces: `ProfileRepo`

## Acceptance Scenarios

1. **Given** a &quot;quoted&quot; label **When** 062 renders **Then** the label renders escaped.
   **Type**: widget

