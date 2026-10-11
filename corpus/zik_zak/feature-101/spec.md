# Spec: 101 (epic: commerce)

**Template Version**: `zuraffa-1.0`

## Layer Contracts — epic-level

**Domain**:
- `ReceiptRepo`: `save(Receipt) -> void`

**Function**:
- `ReceiptTotal`: `compute(List<Receipt>) -> num`

## Functional Requirements

- **FR-001**: The system MUST compute the 101 total via the epic contract.
  traces: `ReceiptTotal.compute`

## Acceptance Scenarios

1. **Given** two items **When** the total computes **Then** the sum renders.
   **Type**: acceptance

