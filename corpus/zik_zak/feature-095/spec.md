# Spec: 095

**Template Version**: `zuraffa-1.0`

## Layer Contracts

**Domain**:
- `Total`: `compute(List<Ticket>) -> num`
- `Counter`: `count(List<Ticket>) -> int`

## Functional Requirements

- **FR-001**: The system MUST compute the 095 total.
  traces: Total
- **FR-002**: The system MUST show the Ticket count.
  traces: Counter

## Scenarios

1. Given a filled cart, When the user opens 095, Then the total renders.
2. Given a partially filled cart,
   When the user opens 095,
   Then the partial total renders.
3. Given an empty cart, When the user opens 095, Then the zero total renders.

