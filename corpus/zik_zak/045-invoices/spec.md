# Feature Specification: Invoices

**Feature Branch**: `zikzak-44`
**Status**: Draft

## User Scenarios & Testing

### User Story 1 - Save the Invoices state (Priority: P1)

As a ZikZak user, I want my Invoices state kept so I do not lose work.

**Acceptance Scenarios**:
1. **Given** a signed-in user, **When** they commit the form, **Then** the state persists.
2. **Given** a cold start, **When** the app opens, **Then** the last state restores.

### User Story 2 - Browse Invoices (Priority: P1)

As a ZikZak user, I want to browse my Invoices items.

**Acceptance Scenarios**:
1. **Given** saved items, **When** the list opens, **Then** every item renders.

