# Spec: Consent Center

**Template Version**: `zuraffa-1.0`

## Functional Requirements

- **FR-001**: The system MUST compute the Consent Center total.
- **FR-002**: The system MUST show the Message count.

## Scenarios

1. Given a filled cart, When the user opens Consent Center, Then the total renders.
2. Given a partially filled cart,
   When the user opens Consent Center,
   Then the partial total renders.
3. Given an empty cart, When the user opens Consent Center, Then the zero total renders.

