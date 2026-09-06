# Feature Specification: Ar Preview

**Feature Branch**: `zikzak-109`
**Status**: Draft

## User Scenarios & Testing

### User Story 1 - Save the Ar Preview state (Priority: P1)

As a ZikZak user, I want my Ar Preview state kept so I do not lose work.

**Acceptance Scenarios**:
1. **Given** a signed-in user, **When** they commit the form, **Then** the state persists.
2. **Given** a cold start, **When** the app opens, **Then** the last state restores.

### User Story 2 - Browse Ar Preview (Priority: P1)

As a ZikZak user, I want to browse my Ar Preview items.

**Acceptance Scenarios**:
1. **Given** saved items, **When** the list opens, **Then** every item renders.

