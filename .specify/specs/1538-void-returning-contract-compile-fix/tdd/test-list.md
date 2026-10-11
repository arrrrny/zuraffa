---
feature: 1538-void-returning-contract-compile-fix
loop: inside-out
profile: .specify/memory/tdd-profile.md
spec_criteria: 5
planned_at: 46fe766e
updated_at: 46fe766e
suite_baseline: green
---

# Test List: Void-returning contracts emit a compiling guard (issue #1538)

Pure writer-template work in `BehaviorTestWriter._captureInvocation` — the
observable is the emitted test file's content and its compilability, so the
loop is inside-out: every behavior is a unit behavior on the writer pair
(test + subject rendered through `write()` into temp fixtures). One behavior
per line, traced to the spec's success criteria.

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/services/behavior_test_writer.dart` (`_captureInvocation`)

| id | behavior                                                                                     | traces   | kind             | state | test                                                                                                     |
| --- | -------------------------------------------------------------------------------------------- | -------- | ---------------- | ----- | -------------------------------------------------------------------------------------------------------- |
| A1  | A void scalar-param contract emits the statement-based void-safe capture — never `return subject.` / the IIFE | SC-1     | example          | DONE  | `test/plugins/tdd/services/bug_1538_void_guard_compile_test.dart::A1` |
| A2  | A void entity-param contract keeps the `_argN()` placeholder helpers before the void-safe capture (the symptom shape) | SC-1     | example          | DONE  | `test/plugins/tdd/services/bug_1538_void_guard_compile_test.dart::A2` |
| A3  | The void test carries the vacuous-guard marker, has the guard as its only expectation, and classifies as the traced hand-delta seam (`contentIsVacuousGreen` + `contentCarriesVacuousGuardMarker`) — no typed outcome assertion | SC-3     | example          | DONE  | `test/plugins/tdd/services/bug_1538_void_guard_compile_test.dart::A3` |
| B1  | A non-void scalar contract keeps the IIFE capture byte-for-byte (`final result = (() {` + `return subject.…` + `isA<T>()`) | SC-2     | characterization | DONE  | `test/plugins/tdd/services/bug_1538_void_guard_compile_test.dart::B1` |
| B2  | A non-void entity-return contract keeps the IIFE + vacuous-guard marker guard (characterization) | SC-2     | characterization | DONE  | `test/plugins/tdd/services/bug_1538_void_guard_compile_test.dart::B2` |
| C1  | The emitted void pair (test + `void` subject stub) compiles and fails through an assertion under `dart test` — never `compile-time error` | SC-4     | example          | DONE  | `test/plugins/tdd/services/bug_1538_void_guard_compile_test.dart::C1` (tags: slow) |

## Invariants and edge cases still to place

- `Future<void>` declared returns are NOT the void path (the IIFE returns the
  Future object — compiles); intentionally unpinned to avoid freezing an
  unrelated surface. If a future spec makes `Future<void>` void-captured,
  that is a behavior change, not this one.
- SC-5 (`dart analyze` no-new-issues) is a verification gate, not a behavior
  row — see `tdd/verification.md`.
