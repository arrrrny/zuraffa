**Template Version**: `zuraffa-1.0`

# Spec: 120

## Layer Contracts

**Domain**:
- `LaneShipper`: `ship(String) -> void`

## Functional Requirements

- **FR-001**: The system MUST ship the 120 lane.
  traces: LaneShipper

## Acceptance Scenarios

1. **Given** a release build **When** the lane opens **Then** the 120 screen renders.
   **Type**: widget
2. **Given** a release build **When** the beta banner shows (manual: @qa-zikzak) **Then** the banner renders.
3. **Given** a support request **When** the user files feedback **Then** the ticket is created.
   **Type**: acceptance
