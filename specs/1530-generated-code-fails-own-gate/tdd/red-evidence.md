# Red Evidence — 1530-generated-code-fails-own-gate

Command: `dart test test/utils/zuraffa_barrel_exports_test.dart` and
`dart test test/plugins/datasource/barrel_hide_unverified_1530_test.dart`
(Dart SDK 3.13.3, branch `feat/1530-generated-code-fails-own-gate`)

## RED run 1 — barrel-exports unit lane (T004/T006/T007 expectations)

```
00:00 +5 -4: Some tests failed.

Failing tests:
  a declared-but-not-shown name does NOT verify        (FR-002: show combinator ignored — over-collection)
  a hidden name does NOT verify                        (FR-002: hide combinator ignored — over-collection)
  a one-level-down directory-relative name verifies    (FR-003: lib-root join drops nested names)
  unresolved → the hide combinator is dropped entirely (FR-001: legacy keep-all fallback emits unverified names)
```

The 4 pre-existing seeded-path guards passed (verified filter basics +
the #942 `EntityNotFound` collision case) — the green baseline the fix
must preserve.

## RED run 2 — generated-output probe lane (T008/U1)

Fixture: hermetic temp target, entity `Task` + `task.dart` present (the
faithful dogfood precondition), NO zuraffa barrel seed (the dogfood
package-config state).

```
00:00 +0 -3: Some tests failed.

Failing tests:
  local datasource emission drops the unverified hide combinator
  remote datasource emission drops the unverified hide combinator
  mock datasource emission drops the unverified hide combinator
```

Each failure is the literal issue-1530 emission: with no resolvable
barrel the builders baked `hide Task, TaskPatch` (local/remote,
`package:zuraffa/zuraffa.dart`) and `hide Task` (mock,
`package:zuraffa/mock.dart`) into generated files.

## TDD plan tasks certified red

- T004 (A-1530-1 / FR-001): `unresolved → dropped entirely` — RED
- T006 (A-1530-3 / FR-002): `shown-only verifies` + `hidden does NOT verify` — RED
- T007 (A-1530-4 / FR-003): nested directory-relative — RED
- T008 (U1 / FR-004): generated-output probe, local+remote+mock — RED
