# Spec: Calendar Sync (epic: commerce)

**Template Version**: `zuraffa-1.0`

## Layer Contracts — epic-level

**Domain**:
- `MessageRepo`: `save(Message) -> void`

**Function**:
- `MessageTotal`: `compute(List<Message>) -> num`

## Functional Requirements

- **FR-001**: The system MUST compute the Calendar Sync total via the epic contract.
  traces: `MessageTotal.compute`

## Acceptance Scenarios

1. **Given** two items **When** the total computes **Then** the sum renders.
   **Type**: acceptance

