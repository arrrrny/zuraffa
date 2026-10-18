# Engine Plan: 004-login-ui (CORE + BOTH)

The engine lane (issue #1000): pure Dart — behaviors whose lane is CORE or BOTH. The noFlutter guard rejects any behavior that references Flutter at plan time, so this file stays engine-only.

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the session starts with the authenticated user | AC-1 | PENDING |
| A2 | the error is reported to the caller | AC-2 | PENDING |
| A3 | the app shows 'Sign in' | AC-3 | PENDING |
| A4 | the app navigates to the route 'deal_list' | AC-4 | PENDING |
| A5 | the 'Sign in failed' banner is not shown | AC-5 | PENDING |
| A6 | the 'Sign in' button is disabled | AC-6 | PENDING |
| A7 | while the sign-in request is in flight the app shows 'Signing in…' and then the app navigates to the route 'deal_list' | AC-7 | PENDING |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The system shall present the adaptive login view with the declared platform slots (mobile, ios, android, macos). | FR-001, adaptive_layouts | PENDING |
| U2 | The system shall gate form submission on the credential verdict: a credential pair is submittable only when the email is well-formed and the password satisfies the declared policy. | FR-002, LoginValidation.isSubmittable | PENDING |

## Contract loop: contract behaviors

One per declared entity method, controller method and usecase in `spec.md` Layer Contracts (issue #1007). A contract test proves the implementation satisfies the DECLARED contract — a failing contract test is BLOCKED (never RED) and blocks the cycle from proceeding to GREEN.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| contract:A1 | LoginValidation.isSubmittable(String email, String password) -> bool (interface method contract) | LoginValidation.isSubmittable | PENDING |


