# Test list — spec 1117 engine-trust-tier-tests

## Key Entities

| Entity | Fields |
| --- | --- |
| Login (entity lane) | id:String |
| AuthSession | token:String |
| LoginParams | kind:String |

## Engine loop:

| ID | description | FR | state |
| --- | --- | --- | --- |
| B-001 | UseCase structural: exactly one usecase file at the pilot path with the LoginUseCase class, imports, execute signature, service delegation, cancel guard | SC-1 | DONE |
| B-002 | UseCase DI structural: login_usecase_di.dart registers through the unregister-first pattern (the pilot's non-idempotency bug pinned) | SC-3 | DONE |
| B-003 | UseCase compile: the generated service + usecase pair analyzes with zero errors in a consumer package | SC-1 | DONE |
| B-004 | UseCase behavioral (a): returns the Service's Future<T> — the exact instance surfaces as Success | SC-3 | DONE |
| B-005 | UseCase behavioral (b): surfaces Result.failure when the Service throws | SC-3 | DONE |
| B-006 | UseCase behavioral (c): the failure path goes through the same sealed AppFailure (the pilot's _FailingAuthService shape) | SC-3 | DONE |
| B-007 | UseCase behavioral (d): registerLoginUseCase(getIt) twice is a no-throw re-registration (idempotent DI, executable) | SC-3 | DONE |
| B-008 | Service structural: AuthService interface at the canonical path with the login signature + entity imports | SC-1 | DONE |
| B-009 | Service compile: the generated interface analyzes with zero errors | SC-1 | DONE |
| B-010 | Repository simple variant: full engine method set delegating to the single datasource | SC-5 | DONE |
| B-011 | Repository synced variant: local-first writes + the sync surface (markPending/markDeleted, syncPending/pullRemote) | SC-5 | DONE |
| B-012 | Repository append variant: the login method appended to BOTH the interface and the data implementation | SC-5 | DONE |
| B-013 | Repository compile: engine-method-set pair (interface + impl + datasource + Patch member) analyzes with zero errors | SC-1 | DONE |
| B-014 | DataSource simple lane: engine method set on the interface with the stub remote implementation | SC-5 | DONE |
| B-015 | DataSource synced lane: local implementation emitted alongside interface and remote | SC-5 | DONE |
| B-016 | DataSource append lane: appended engine methods land on the existing interface + remote | SC-5 | DONE |
| B-017 | DataSource compile: engine-method-set pair analyzes with zero errors | SC-1 | DONE |
| B-018 | MockProvider structural: AuthMockProvider implements the service with the certified 100 ms delay default and the expected stub body | SC-1 | DONE |
| B-019 | MockProvider structural (#1034): the per-method fixture selector threads AuthSessionMockData.forMethod(params.kind) | SC-4 | DONE |
| B-020 | MockProvider compile: provider + mock data + simulation binding analyze with zero errors | SC-1 | DONE |
| B-021 | MockProvider behavioral (a): every method satisfies the contract (isA<AuthService>, returns the entity) | SC-4 | DONE |
| B-022 | MockProvider behavioral (b): delay constructor parameter honored — 100 ms default, Duration.zero short-circuits | SC-4 | DONE |
| B-023 | MockProvider behavioral (c): the per-method fixture selector routes on the params discriminator (#1034, executable) | SC-4 | DONE |
| B-024 | #1044 discipline: every behavioral run executes through the tdd-profile-resolved runner, never a literal dart test | SC-1 | DONE |

## Skin loop:

| ID | description | FR | state |
| --- | --- | --- | --- |
| (none — engine-tier spec; the skin trust tier is #1003's closed lineage) | | | |
