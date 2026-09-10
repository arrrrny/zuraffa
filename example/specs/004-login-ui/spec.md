**Template Version**: `zuraffa-1.0`

# Feature Specification: 004-login-ui — the adaptive login skin

The login skin of the ZIKZAK rebuild fleet, re-split under the issue
#1005 hand-written seam: the view is hand-written, the loop referees
it against the declared contract.

EPIC 1133 (TDD Loop Completeness): the acceptance corpus now carries the
full finder-kind taxonomy (issue #964) — every scenario verb maps to a
machine-certified assertion kind (`shows` → presence, `navigates` →
route outcome, `is not shown` → absence, `is disabled` → enabled-state,
`while … in flight` → sequence) — and the i18n-keyed widget contract
(issue #965): every user-facing surface declares a slang key with the EN
literal as the anchor, never a pinned EN literal.

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
   **Type**: acceptance

2. **Given** invalid credentials **When** the login attempt fails **Then** the error is reported to the caller
   **Type**: acceptance

3. **Given** the login view **When** it renders **Then** the app shows 'Sign in'
   **Type**: widget

4. **Given** a completed sign-in **When** the user signs in **Then** the app navigates to the route 'deal_list'
   **Type**: widget

5. **Given** a fresh login view **When** no sign-in attempt has failed **Then** the 'Sign in failed' banner is not shown
   **Type**: widget

6. **Given** an empty form **When** validation runs **Then** the 'Sign in' button is disabled
   **Type**: widget

7. **Given** a submitted form **Then** while the sign-in request is in flight the app shows 'Signing in…' and then the app navigates to the route 'deal_list'
   **Type**: widget

## Functional Requirements

- **FR-001**: The system shall present the adaptive login view with the declared platform slots (mobile, ios, android, macos).
      traces: adaptive_layouts

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A2, U1]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [W1, A3, A4, A5, A6, A7]
    flutter_allowed: true
    adaptive_slots: [mobile, ios, android, macos]
```

## Layer Contracts

**Presentation**:

- `LoginView`: `key: auth.signIn -> 'Sign in'`, `key: auth.error -> 'Sign in failed'`, `key: auth.working -> 'Signing in…'`

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

## Layer Contracts

The i18n-keyed presentation contract (issue #1141, extending #965): the
login surfaces the production ZikZak view renders through slang keys
(`t.auth.signIn`, …) are declared as `key:` tokens with the EN literal
as the human-readable anchor and the non-i18n fallback — the contract a
regenerated view (or the hand-written seam below it) is audited
against. Every quoted user-facing string must trace to one of these
rows; a declared anchor renders through the accessor, never the EN
literal.

**Presentation**:
- `LoginForm`: `ShadInput` for email and password, `key: auth.signIn -> 'Sign in'`, `key: auth.email -> 'Email'`, `key: auth.password -> 'Password'`, `key: auth.sessionStarted -> 'Session started'`
- `adaptive_layouts`: `mobile`, `macos`

The platform layout contract (issue #1142, extending #1004's
`adaptive_slots` and #1102's runtime auditor): the Presentation table
declares the platform layout slots per feature — a regenerated view
emits the AdaptiveViewState skeleton with one layout stub per declared
slot (mobile, macos), each traced independently in the coverage ledger
(a "mobile-only 100% traced" login is still missing macOS coverage).
The slots are the scaffold-builder targets plus the SkinEvent slots the
hand-written seam emits (`mobile`, `ios`, `android`, `macos`); this
fixture declares the two the regenerated skeleton must provide.

