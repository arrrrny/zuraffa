# Test List: 1001-certified-mocks-contract-tests

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | `zfa mock create Login --certify` generates the mock, runs the contract test in a temp sandbox (dart analyze + dart test), exits 0, and writes `mock-cert.Login.json` with every method `satisfied: true` and the contract digest. | US1 | DONE |
| A2 | the auto-generated contract test (`test/mock/<snake>/<snake>_mock_contract_test.dart`) pins every interface method through the INTERFACE type (typed tear-offs + behavioral invocations) and is committed into the project. | US1 | DONE |
| A3 | `--certify` on a mock-less entity refuses honestly (no receipt lies; the refusal names the fix). | US1 | DONE |
| A4 | removing a method from the repository interface makes the committed contract test fail (red) — `zfa mock certify` exits 3 with a drift diagnostic. | US2 | DONE |
| A5 | a red re-certification overwrites the on-disk receipt with per-method `satisfied: false` (the run-engine gate never reads a stale green receipt). | US2 | DONE |
| A6 | `zfa mock certify <Entity>` registers the mock in the #832 registry entry: receipt committed as a fixture, manifest `mocks:` provenance, receipt hashed into the world digest, `kind: mock-cert` cycle-log evidence; tampering trips `verifyManifest`. | US3 | DONE |
| A7 | `zfa mock create <Entity> --seed=42` produces byte-identical output to a second run with the same seed; records derive from the seed; different seeds differ; no-seed output unchanged. | US4 | DONE |
| A8 | `zfa tdd run-engine <feature>` refuses to proceed (exit 1, `blocked=<entity>`) when any CORE (declared Key Entity) mock is present but uncertified; certified/absent mocks proceed (exit 0). | US5 | DONE |
| A9 | `zfa tdd run <feature>` runs the same gate as a pre-start preflight and stops with `result=runner-error` when a CORE mock is uncertified. | US5 | DONE |
| A10 | `--certify` / `--seed` materialize through the CapabilityCommand schema bridge (integer coercion, issue #773 path) and `zfa mock certify` owns its exit-code contract. | US1/US4 | DONE |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | MockContractTestWriter.extractContract pins every interface method with raw (Future/Stream-wrapped) signatures; null when the interface is absent. | A2 | DONE |
| U2 | render synthesizes behavioral invocations for canonical param types (QueryParams / ListQueryParams / UpdateParams / ToggleParams / DeleteParams / entity) and degrades to the signature pin otherwise. | A2 | DONE |
| U3 | MockCertReceipt roundtrips (per-method proof, digest, seed); corrupt receipts are not certifications; allSatisfied requires a non-empty all-true contract. | A1/A5 | DONE |
| U4 | FixtureRegistry.writeManifest records `mocks:` provenance; certifyMockInRegistry preserves families + prior mocks; the cycle-log chain links per-entity behaviors. | A6 | DONE |
| U5 | The seed threads baseSeed through MockValueBuilder/MockDataBuilder (records N, N+1, N+2) and the JSON path pins DateTime values + meta to seed-derived values when seeded. | A7 | DONE |
| U6 | The run-engine gate distinguishes: no mock (proceed), mock + all-satisfied receipt (proceed), receipt missing/corrupt/unsatisfied (refuse, name entity). | A8 | DONE |
