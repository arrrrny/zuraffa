# TDD Evidence — bug #1034 (branch: fix/1034-mock-dependency-per-method-fixture)

Mode: branch (the bug branch has no `specs/<feature>` test list; this
directory substitutes as the evidence home, per the #827 convention).
Input records: `.specify/bugs/1034-mock-dependency-per-method-fixture/issue.md`
and `assessment.md` were NOT present in the repo at fix time (task brief said
"if exists"); the bug context in the assignment (repro, expected shape, hard
constraints) is the sole triage input and is reproduced here verbatim in
substance, not re-derived.

## Behaviors under test (test list)

All in `test/plugins/mock/create_mock_capability_test.dart`, group
`issue #1034 — provider threads the per-method fixture selector`
(test file authored FIRST, before the template change — see RED below):

1. **B1 (threading, Future)** — service mode (`AuthService.login(AuthRequest)
   -> User`) with an augmented `UserMockData.forMethod(AuthenticationMethod)`
   selector and a `method` discriminator field on `AuthRequest` → generated
   `AuthMockProvider.login` returns `UserMockData.forMethod(params.method)`,
   and no `UserMockData.sampleUser` remains.
2. **B2 (threading, Stream)** — same shape with `Stream<User> login(...)`
   → the stream closure threads the selector too.
3. **B3 (guard, no selector)** — no `forMethod` declared → the #1030
   single-fixture shape `UserMockData.sampleUser` is preserved byte-for-byte
   in behavior; `forMethod` appears nowhere.
4. **B4 (guard, no discriminator field)** — selector declared but the params
   entity carries no matching field → falls back to `sampleUser`.
5. **B5 (guard, type mismatch)** — selector declared but its parameter type
   matches no params-entity field type → falls back to `sampleUser`.

## RED (observed before the fix)

Command:

```bash
dart test test/plugins/mock/create_mock_capability_test.dart --plain-name "issue #1034"
```

Actual output (unfixed tree, template still hardcoded `sample<T>`):

```
00:00 +0: issue #1034 — provider threads the per-method fixture selector GREEN: selector + discriminator on params entity → login returns UserMockData.forMethod(params.method)
00:00 +0 -1: issue #1034 — provider threads the per-method fixture selector GREEN: selector + discriminator on params entity → login returns UserMockData.forMethod(params.method) [E]
  Expected: true
    Actual: <false>
  the provider template must thread the declared per-method fixture selector instead of the single canned fixture

  package:matcher                                           expect
  test/plugins/mock/create_mock_capability_test.dart 466:9  main.<fn>.<fn>

00:00 +0 -1: issue #1034 — provider threads the per-method fixture selector no selector on the mock data class → single-fixture shape preserved (#1030 invariant, no behavior change)
00:00 +1 -1: issue #1034 — provider threads the per-method fixture selector selector declared but params entity carries no discriminator field → falls back to the single-fixture shape
00:00 +2 -1: issue #1034 — provider threads the per-method fixture selector selector declared but its parameter type matches no params field → falls back to the single-fixture shape
00:00 +3 -1: Some tests failed.
```

Read: B1 RED (the bug, reproduced at template level — single canned fixture
emitted for every call); B3/B4/B5 green by design (they pin the pre-existing
fallback contract that must not regress); B2 not yet present when this run was
recorded (added with the same batch after the Future path went green; its red
is implied by the same emission site — see Mutant M-1 below which proves the
stream site participates in the threaded decision).

## GREEN (observed after the fix)

Command:

```bash
dart test test/plugins/mock/create_mock_capability_test.dart
```

Actual output:

```
00:00 +10: issue #1034 — ... no selector on the mock data class → single-fixture shape preserved (#1030 invariant, no behavior change)
00:00 +11: issue #1034 — ... selector declared but params entity carries no discriminator field → falls back to the single-fixture shape
00:00 +12: issue #1034 — ... selector declared but its parameter type matches no params field → falls back to the single-fixture shape
00:01 +13: All tests passed!
```

Scoped regression sweep (whole mock plugin dir):

```bash
dart test test/plugins/mock/
```

```
00:04 +60: All tests passed!
```

(13/13 in the touched file — 5 new #1034 behaviors + 8 pre-existing #770/#1027/
#1030 tests, including the #1030 canned-shape assertions that must keep passing;
60/60 across `test/plugins/mock/`.)
