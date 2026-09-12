# Spec: 066

**Template Version**: `zuraffa-1.0`

## Key Entities

| Entity | Fields | Purpose |
| -- | -- | -- |
| BookmarkMeta | `label: String` | display name |

## External Dependencies &amp; Contracts

| Dependency | Type | Contract | Mock Priority |
| -- | -- | -- | -- |
| Hive | storage: box | `put(String, dynamic) -> void` | high |

## Layer Contracts

**Domain**:
- `BookmarkRepo`: `get(String) -> Bookmark?`

## Functional Requirements

- **FR-001**: The system MUST escape the &quot;quoted&quot; label.
  traces: `BookmarkRepo`
- **FR-002**: The system MUST reject values with &lt;script&gt; content.
  traces: `BookmarkRepo`

## Acceptance Scenarios

1. **Given** a &quot;quoted&quot; label **When** 066 renders **Then** the label renders escaped.
   **Type**: widget

