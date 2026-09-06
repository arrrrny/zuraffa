# Feature Specification: Splits

**Feature Branch**: `zikzak-49`
**Status**: Draft

## User Scenarios & Testing

### User Story 1 - Save the Splits state (Priority: P1)

As a ZikZak user, I want my Splits state kept so I do not lose work.

**Acceptance Scenarios**:
1. **Given** a signed-in user, **When** they commit the form, **Then** the state persists.
2. **Given** a cold start, **When** the app opens, **Then** the last state restores.

### User Story 2 - Browse Splits (Priority: P1)

As a ZikZak user, I want to browse my Splits items.

**Acceptance Scenarios**:
1. **Given** saved items, **When** the list opens, **Then** every item renders.

