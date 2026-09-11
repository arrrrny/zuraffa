# Spec: 098

**Template Version**: `zuraffa-1.0`

## Layer Contracts

**Domain**:
- `Total`: `compute(List<Profile>) -> num`
- `Counter`: `count(List<Profile>) -> int`

## Functional Requirements

- **FR-001**: The system MUST compute the 098 total.
  traces: Total
- **FR-002**: The system MUST show the Profile count.
  traces: Counter

## Scenarios

1. Given a filled cart, When the user opens 098, Then the total renders.
2. Given a partially filled cart,
   When the user opens 098,
   Then the partial total renders.
3. Given an empty cart, When the user opens 098, Then the zero total renders.

