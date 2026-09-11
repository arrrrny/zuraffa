# Spec: 084

**Template Version**: `zuraffa-1.0`

## Functional Requirements

- **FR-001**: The system MUST validate the 084 form before submit.
  traces: FormValidator
- **FR-002**: The system MUST submit the validated Report.
  traces: ReportSubmitter

## Scenarios

### Story A — happy path

1.1. **Given** a valid form **When** the user submits **Then** the Report is saved.
1.2. **Given** a saved Report **When** the user reopens 084 **Then** the row renders.

### Story B — validation

2.1. **Given** an invalid field **When** the user submits **Then** an error message renders.
2.2. **Given** an offline device **When** the user submits **Then** the queued state renders.

