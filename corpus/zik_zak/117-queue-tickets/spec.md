**Template Version**: `zuraffa-1.0`

# Spec: Queue Tickets

## Functional Requirements

- **FR-001**: The system MUST ship the Queue Tickets lane.

## Acceptance Scenarios

1. **Given** a release build **When** the lane opens **Then** the Queue Tickets screen renders.
   **Type**: widget
2. **Given** a release build **When** the beta banner shows (manual: ) **Then** the banner renders.
3. **Given** a support request **When** the user files feedback **Then** the ticket is created.
   **Type**: acceptance
