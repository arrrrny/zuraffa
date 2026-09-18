# Bug Test: scalar vacuous-green refusal prints the void/entity explanation

- **Slug**: 1677-scalar-vacuous-green-message
- **Written**: 2026-09-18 (RED before the fix, this session)
- **Suite**: test/plugins/tdd/commands/bug_1677_scalar_vacuous_message_test.dart
- **Tier**: slow (driver level — the REAL RunDriverCore over a scripted
  fake zfa binary; run with `dart test --preset=all <file>`, the
  documented single-slow-file invocation)

## Behaviors

| id | description | traces | result |
| -- | ----------- | ------ | ------ |
| U1 | a scalar contract's vacuous-green refusal prints the #1651 scalar explanation — the declared return TYPE check the func dummy satisfies — and never the #1308 void/entity template; `stopped_at=U1:hand` and the `hand step:` line unchanged | issue #1677 (scalar branch) | RED → GREEN |
| U2 | a void/entity contract's vacuous-green refusal keeps the #1308 hand-delta-seam explanation byte-for-byte; the scalar template never fires; `stopped_at=U1:hand` and the `hand step:` line unchanged | issue #1677 (void/entity branch) | GREEN (guard pin) |

## Fixtures

- The fake zfa binary scripts the pipeline honestly: gen exits 0 silent,
  verify-red certifies an assertion-failure red into the cycle log, make
  refuses with `outcome=vacuous-green` (the #1308/#1651 harness shape).
- U1's generated test is the #1651 writer's exact scalar emission: the
  capture, the `typeOnlyVacuousGuardComment` marker block, and
  `expect(result, isA<int>())` — the shape a scalar contract row
  (`add(int a, int b) -> int`, traces `FR-001, Calculator`) produces.
- U2's generated test is the #1259 writer's void/entity emission: the
  marker block plus the bare `expect(result,
  isNot(isA<UnimplementedError>()))` guard.

## Assertions (U1, the repro)

1. The stop is the honest vacuous-green one:
   `behavior=U1 step=make outcome=vacuous-green`.
2. The machine contract is UNCHANGED: `stopped_at=U1:hand`, never
   `stopped_at=U1:make` (marker presence stays the `:hand`
   discriminator — issue #1308 semantics preserved).
3. THE FIX: the refusal names the scalar branch —
   `the traced contract's return is scalar (int)`, `checks the declared
   return TYPE only`, `(issue #1651)`.
4. The false template is GONE: neither `the traced contract's return is
   void/an entity` nor `the assertion set is the UnimplementedError
   guard only` may appear.
5. The `hand step:` line is UNCHANGED: `hand step: U1:hand — write an
   assertion on the observable outcome ...`.

## Assertions (U2, the guard)

1. `stopped_at=U1:hand` (unchanged machine contract).
2. The #1308 wording stands: `the traced contract's return is void/an
   entity`, `the designed hand-delta seam`, `(issue #1308)`.
3. The scalar template never fires for a void/entity contract: no
   `the traced contract's return is scalar`.
4. The `hand step:` line is unchanged.

## Results

- RED (pre-fix): U1 failed for the right reason (the void/entity template
  printed for the scalar shape); U2 green. Verbatim evidence in
  `tdd/test-list.md`.
- GREEN (post-fix): `+2: All tests passed!`

## Review Hardening (PR #1701)

| id | description | traces | result |
| -- | ----------- | ------ | ------ |
| U3 | two type-only expects over different scalars (hand-authored marker-carrying variant) — the refusal names BOTH distinct types in first-occurrence order, duplicate collapsed: `the traced contract's return is scalar (int, String)`; machine contract and `hand step:` line unchanged | review of PR #1701 (plural pin) | GREEN |
