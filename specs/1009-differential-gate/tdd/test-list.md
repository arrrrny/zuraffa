# Test List: 1009-differential-gate

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | `zfa tdd realize-mock Login --against=firestore` exits 0 with a clean receipt: every method `tier1_result: pass`, `tier2_result: pass`, `diff: none`, `result: certified` (driven through the real CLI in a throwaway project). | US1 | DONE |
| A2 | the differential receipt `test/mock/<snake>/realize.<Entity>.firestore.receipt.json` records per-method `{method, tier1_result, tier2_result, diff}`, the tier-1 contract digest, the tier-2 swapped-test digest, and per-tier sandbox evidence. | US1/US4 | DONE |
| A3 | a proof.v1 generation receipt covers the differential receipt's bytes in `.zfa/receipts/`; `zfa proof check` verifies it with zero findings. | US4 | DONE |
| A4 | a divergent method (tier-2 returns a wrong-typed value — `--diverge get`) exits 1, names the method in stdout (`divergence=get`) and in the receipt (`get: tier1 pass / tier2 fail / diff mismatch`). | US2 | DONE |
| A5 | `--diverge` naming an unknown method or a Stream-returning method refuses (exit 2) instead of guessing. | US2 | DONE |
| A6 | a red Tier-1 baseline with no divergence refuses as `result=tier1-red` (exit 2) with the certify fix hint — never a mismatch, never a certification. | US3 | DONE |
| A7 | usage and artifact refusals are errors-are-an-API: missing entity / missing `--against` / unsupported backend (only `firestore`) / missing committed contract test each exit 2 naming the fix. | US1 | DONE |

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | `RealizeMockMethodResult.diff` is `mismatch` iff the tiers disagree; both-pass and both-fail are `none` (the disagreement is the divergence). | A2 | DONE |
| U2 | the gate verdict: any divergence → `mismatch`; else any tier-1 failure → `tier1-red`; else `certified` (a red-red pair is never certified). | A6 | DONE |
| U3 | the receipt round-trips through `fromJson` (every row, verdict, digests); missing/corrupt receipts load as null, never a guess; the canonical path names entity + backend. | A2/A3 | DONE |
| U4 | the Tier-2 adapter renders `with Loggable, FailureHandler implements <Entity>DataSource` (the interface's mixins are satisfied the same way the Tier-1 mock satisfies them), imports the entity/interface/mock data, and routes through FakeFirebaseFirestore. | A1 | DONE |
| U5 | every interface method is overridden with the exact signature; only the helpers the method set uses are emitted; the seed derives doc ids from the entity id field (synthetic `doc-<i>` keys when the entity has no scalar id). | A1 | DONE |
| U6 | `--diverge` injects a wrong-typed return (`_divergentValue as <T>`) on the named method only; the other methods keep conforming bodies. | A4 | DONE |
| U7 | `swapSubject` replaces exactly one import + one `<Entity>MockDataSource()` construction with the Tier-2 provider (every pin byte-identical) and refuses (StateError) when the construction-site count is not exactly one. | A1 | DONE |
| U8 | the command (sandbox runner injected) drives the gate: clean → exit 0 + proof check verifies; mismatch → exit 1 + named method; tier-1-red → exit 2 refusal; the tier-2 run carries the adapter as an extra sandbox file. | A1/A4/A6 | DONE |
| U9 | the certification sandbox writes `extraFiles` at their project-relative positions before pub get/analyze/test (the spec-1001 semantics are unchanged when omitted). | A1 | DONE |
