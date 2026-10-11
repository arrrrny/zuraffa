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
| U2 | The system shall gate form submission on the credential verdict: a credential pair is submittable only when the email is well-formed and the password satisfies the declared policy. | FR-002, LoginValidation.isSubmittable | PENDING |

## Layer contracts

### Presentation

- `LoginView`: `key: auth.signIn -> 'Sign in'`, `key: auth.error -> 'Sign in failed'`, `key: auth.working -> 'Signing in…'`
- `LoginForm`: `ShadInput`, `key: auth.signIn -> 'Sign in'`, `key: auth.email -> 'Email'`, `key: auth.password -> 'Password'`, `key: auth.sessionStarted -> 'Session started'`
- `adaptive_layouts`: `mobile`, `macos`
### Function

- `LoginValidation`: `isSubmittable(String email, String password) -> bool`

## Routing provenance

Per-behavior routing decisions (issue #951): what each decision consulted — a declared marker/contract row, or the labeled legacy fallback to migrate.

route: A1 -> acceptance lane [declared: type marker, spec line 20]
route: A2 -> acceptance lane [declared: type marker, spec line 23]
route: U2 -> unit lane (func surface) [declared: contract row: LoginValidation, spec line 69]
route: contract:A1 -> contract lane [declared: LoginValidation]


