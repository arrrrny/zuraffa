# Engine Plan: 004-login-ui (CORE + BOTH)

The engine lane (issue #1000): pure Dart — behaviors whose lane is CORE or BOTH. The noFlutter guard rejects any behavior that references Flutter at plan time, so this file stays engine-only.

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | the session starts with the authenticated user | AC-1 | PENDING |
| A2 | the error is reported to the caller | AC-2 | PENDING |

## Inner loop: unit behaviors

One per functional requirement in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | The system shall present the adaptive login view with the declared platform slots (mobile, ios, android, macos). | FR-001, adaptive_layouts | PENDING |

## Layer contracts

### Presentation

- `LoginView`: `key: auth.signIn -> 'Sign in'`, `key: auth.error -> 'Sign in failed'`, `key: auth.working -> 'Signing in…'`
- `LoginForm`: `ShadInput`, `key: auth.signIn -> 'Sign in'`, `key: auth.email -> 'Email'`, `key: auth.password -> 'Password'`, `key: auth.sessionStarted -> 'Session started'`
- `adaptive_layouts`: `mobile`, `macos`

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: A2 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
route: U1 -> unit lane (view generation) [declared: contract row: adaptive_layouts, spec line 94]


