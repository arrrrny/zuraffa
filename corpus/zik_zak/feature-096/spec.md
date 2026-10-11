# Spec: 096

**Template Version**: `zuraffa-1.0`

## Layer Contracts

**Domain**:
- `Total`: `compute(List<Report>) -> num`
- `Counter`: `count(List<Report>) -> int`

## Functional Requirements

- **FR-001**: The system MUST compute the 096 total.
  traces: Total
- **FR-002**: The system MUST show the Report count.
  traces: Counter

## Scenarios

1. Given a filled cart, When the user opens 096, Then the total renders.
2. Given a partially filled cart,
   When the user opens 096,
   Then the partial total renders.
3. Given an empty cart, When the user opens 096, Then the zero total renders.

