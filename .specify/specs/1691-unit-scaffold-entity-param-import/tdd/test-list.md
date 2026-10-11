# Test List: 1691-unit-scaffold-entity-param-import

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U1 | the paired unit test imports every existing entity the declared signature references — the param entity for the `_argN()` helper's lifted type, the return entity for the `isA<T>()` assertion (param first, deduped) | FR-001, behavior_test_writer._testEntityImportLines | PENDING |
| U2 | an entity param with a SCALAR declared return also imports the param entity — the return-only import set missed the helper's lifted type there too | FR-002, behavior_test_writer._testEntityImportLines | PENDING |
| U3 | a scalar-only contract keeps the legacy template byte-for-byte — representative literals, no `_argN()` helper, no entity import block | FR-003, behavior_test_writer._testEntityImportLines | PENDING |
| U4 | the login_probe repro certifies an honest red: `zfa tdd verify-red U1` classifies `assertion` with `certified=true` after the fix (pristine tree: `compile-error`, `certified=false`) | FR-001, verify_red_command | PENDING |
| U5 | the zcalc probe path (scalar params) certifies an honest red unchanged: classification `assertion`, `certified=true` | FR-003, verify_red_command | PENDING |

## Functional Requirements

- **FR-001**: The unit-lane test scaffold MUST import `shape.entityImports`
  (deduped, param first) so the `_argN()` helper's lifted entity param type
  resolves at compile time.
- **FR-002**: The fix MUST extend to the latent shapes the return-only set
  missed (entity param + scalar return; entity param + non-renderable
  return) — every emitted import is referenced by the test.
- **FR-003**: The fix MUST keep scalar-param behavior unchanged — legacy
  and scalar-only templates stay byte-identical, and no unused import may
  be introduced (entries exist only for on-disk entities, the exact lift
  condition).
