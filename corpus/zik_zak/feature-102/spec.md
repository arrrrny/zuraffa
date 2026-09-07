# Spec: 102 (epic: commerce)

**Template Version**: `zuraffa-1.0`

## Layer Contracts — epic-level

**Domain**:
- `BookmarkRepo`: `save(Bookmark) -> void`

**Function**:
- `BookmarkTotal`: `compute(List<Bookmark>) -> num`

## Functional Requirements

- **FR-001**: The system MUST compute the 102 total via the epic contract.
  traces: `BookmarkTotal.compute`

## Acceptance Scenarios

1. **Given** two items **When** the total computes **Then** the sum renders.
   **Type**: acceptance

