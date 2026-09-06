# Spec: Privacy Dashboard

**Template Version**: `zuraffa-1.0`

## Functional Requirements

- **FR-001**: The system MUST compute the Privacy Dashboard total.
- **FR-002**: The system MUST show the Alert count.

## Scenarios

1. Given a filled cart, When the user opens Privacy Dashboard, Then the total renders.
2. Given a partially filled cart,
   When the user opens Privacy Dashboard,
   Then the partial total renders.
3. Given an empty cart, When the user opens Privacy Dashboard, Then the zero total renders.

