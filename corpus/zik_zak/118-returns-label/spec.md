**Template Version**: `zuraffa-1.0`

# Spec: Returns Label

## Functional Requirements

- **FR-001**: The system MUST ship the Returns Label lane.

## Acceptance Scenarios

1. **Given** a release build **When** the lane opens **Then** the Returns Label screen renders.
   **Type**: widget
2. **Given** a release build **When** the beta banner shows (manual: @qa-zikzak) **Then** the banner renders.
3. **Given** a support request **When** the user files feedback **Then** the ticket is created.
   **Type**: acceptance
