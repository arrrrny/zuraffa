# Spec: Rate App Prompt

**Template Version**: `zuraffa-1.0`

## Functional Requirements

- **FR-001**: The system MUST compute the Rate App Prompt total.
- **FR-002**: The system MUST show the Profile count.

## Scenarios

1. Given a filled cart, When the user opens Rate App Prompt, Then the total renders.
2. Given a partially filled cart,
   When the user opens Rate App Prompt,
   Then the partial total renders.
3. Given an empty cart, When the user opens Rate App Prompt, Then the zero total renders.

