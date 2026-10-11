# Traceability: 004-login-ui

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:033cc6f7e68e79fb50ea58e490a1a5da85efca3e0c1e46bac677419f6e4c46e2
statements: 9
automated: 9
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 19 | 1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user | A1 | automated |
| AC-2 | 22 | 2. **Given** invalid credentials **When** the login attempt fails **Then** the error is reported to the caller | A2 | automated |
| AC-3 | 25 | 3. **Given** the login view **When** it renders **Then** the app shows 'Sign in' | A3 | automated |
| AC-4 | 28 | 4. **Given** a completed sign-in **When** the user signs in **Then** the app navigates to the route 'deal_list' | A4 | automated |
| AC-5 | 31 | 5. **Given** a fresh login view **When** no sign-in attempt has failed **Then** the 'Sign in failed' banner is not shown | A5 | automated |
| AC-6 | 34 | 6. **Given** an empty form **When** validation runs **Then** the 'Sign in' button is disabled | A6 | automated |
| AC-7 | 37 | 7. **Given** a submitted form **Then** while the sign-in request is in flight the app shows 'Signing in…' and then the app navigates to the route 'deal_list' | A7 | automated |
| FR-001 | 42 | - **FR-001**: The system shall present the adaptive login view with the declared platform slots (mobile, ios, android, macos). | U1 | automated |
| FR-002 | 45 | - **FR-002**: The system shall gate form submission on the credential verdict: a credential pair is submittable only when the email is well-formed and the password satisfies the declared policy. | U2 | automated |

