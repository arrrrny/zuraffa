# Feature Specification: Checkout

**Feature Branch**: `zikzak-41`
**Status**: Draft

## User Scenarios & Testing

### User Story 1 - Save the Checkout state (Priority: P1)

As a ZikZak user, I want my Checkout state kept so I do not lose work.

**Acceptance Scenarios**:
1. **Given** a signed-in user, **When** they commit the form, **Then** the state persists.
2. **Given** a cold start, **When** the app opens, **Then** the last state restores.

### User Story 2 - Browse Checkout (Priority: P1)

As a ZikZak user, I want to browse my Checkout items.

**Acceptance Scenarios**:
1. **Given** saved items, **When** the list opens, **Then** every item renders.

