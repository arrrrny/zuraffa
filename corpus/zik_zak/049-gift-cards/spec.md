# Feature Specification: Gift Cards

**Feature Branch**: `zikzak-48`
**Status**: Draft

## User Scenarios & Testing

### User Story 1 - Save the Gift Cards state (Priority: P1)

As a ZikZak user, I want my Gift Cards state kept so I do not lose work.

**Acceptance Scenarios**:
1. **Given** a signed-in user, **When** they commit the form, **Then** the state persists.
2. **Given** a cold start, **When** the app opens, **Then** the last state restores.

### User Story 2 - Browse Gift Cards (Priority: P1)

As a ZikZak user, I want to browse my Gift Cards items.

**Acceptance Scenarios**:
1. **Given** saved items, **When** the list opens, **Then** every item renders.

