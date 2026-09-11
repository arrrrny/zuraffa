# Spec: 093

**Template Version**: `zuraffa-1.0`

## Functional Requirements

- **FR-001**: The system MUST compute the 093 total.
  traces: Total
- **FR-002**: The system MUST show the Notification count.
  traces: Counter

## Scenarios

1. Given a filled cart, When the user opens 093, Then the total renders.
2. Given a partially filled cart,
   When the user opens 093,
   Then the partial total renders.
3. Given an empty cart, When the user opens 093, Then the zero total renders.

