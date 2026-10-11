# Spec: 100 (epic: commerce)

**Template Version**: `zuraffa-1.0`

## Layer Contracts — epic-level

**Domain**:
- `OrderRepo`: `save(Order) -> void`

**Function**:
- `OrderTotal`: `compute(List<Order>) -> num`

## Functional Requirements

- **FR-001**: The system MUST compute the 100 total via the epic contract.
  traces: `OrderTotal.compute`

## Acceptance Scenarios

1. **Given** two items **When** the total computes **Then** the sum renders.
   **Type**: acceptance

