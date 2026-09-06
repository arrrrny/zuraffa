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
    behaviors: [A1, A2, U1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1]
    flutter_allowed: true
    adaptive_slots: [mobile, ios, android, macos]
  - lane: BOTH
    behaviors: [A3 (acceptance: navigates to deal_list)]
    flutter_allowed: conditionally
```

## Skin Contract

The declared skin contract (issue #1004): the adaptive-layout platform
matrix, the per-platform overrides, the view state machine, and the
routes the skin can navigate to — the typed declaration the loop
referees the skin against.

```yaml
Skin Contract:
  adaptive_slots: [mobile, ios, android, macos]
  platform_overrides:
    ios:
      home_indicator_safe_area: required
    macos:
      title_bar_alignment: trailing
  states: [initial, loading, data, error, empty]
  routes: [login, deal_list, settings]
```
