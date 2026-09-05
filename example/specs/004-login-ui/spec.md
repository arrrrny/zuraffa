**Template Version**: `zuraffa-1.0`

# Feature Specification: 004-login-ui — the adaptive login skin

The login skin of the ZIKZAK rebuild fleet, re-split under the issue
#1005 hand-written seam: the view is hand-written, the loop referees
it against the declared contract.

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
2. **Given** invalid credentials **When** the login attempt fails **Then** the error is reported to the caller
3. **Given** a completed login **When** the session is active **Then** the app navigates to deal_list

## Functional Requirements

- **FR-001**: The system shall present the adaptive login view with the declared platform slots (mobile, ios, android, macos).

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [U1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1]
    flutter_allowed: true
    adaptive_slots: [mobile, ios, android, macos]
  - lane: BOTH
    behaviors: [A3]
    flutter_allowed: conditionally
```

## Skin Contract

| Token | Value | Source |
|-------|-------|--------|
| adaptive_slots | mobile, ios, android, macos | Lanes SKIN lane |
| home_indicator_safe_area | required (ios) | platform_overrides |
| title_bar_alignment | trailing (macos) | platform_overrides |
