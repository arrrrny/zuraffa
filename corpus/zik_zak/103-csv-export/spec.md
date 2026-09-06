# Spec: Csv Export (epic: commerce)

**Template Version**: `zuraffa-1.0`

## Layer Contracts — epic-level

**Domain**:
- `AlertRepo`: `save(Alert) -> void`

**Function**:
- `AlertTotal`: `compute(List<Alert>) -> num`

## Functional Requirements

- **FR-001**: The system MUST compute the Csv Export total via the epic contract.
  traces: `AlertTotal.compute`

## Acceptance Scenarios

1. **Given** two items **When** the total computes **Then** the sum renders.
   **Type**: acceptance

