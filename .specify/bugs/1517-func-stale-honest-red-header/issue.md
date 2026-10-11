## Summary
`zfa tdd func` fills a declared stub's body (e.g. `return true;` for a
bool) but preserves the generated stub header and doc comment verbatim.
The surviving text still claims "honest red" / "Throws
[UnimplementedError]" — now false: the paired test compiles and goes green
on the dummy body alone.

## Reproduction (PR #1501, fixture 004-login-ui, U2)

1. `zfa tdd gen U2` emits `u2_subject.dart` with header: "This is a MINIMAL
   COMPILABLE STUB: it does NOT satisfy the behavior — the paired test
   fails on first execution (honest red)." and doc: "Throws
   [UnimplementedError] until the real implementation lands."
2. `zfa tdd func U2` rewrites the body to `return true;` per
   `isSubmittable(String email, String password) -> bool`.
3. Header and doc unchanged — the committed file claims red while the
   suite is green (+1 passed, body `return true;`).

Caught by automated review of #1501; stale text had to be hand-corrected
in commit 9960d905.

## Root cause

`func_command.dart` preserves the stub header verbatim when rewriting the
body (by design, to keep contract traces). The honest-red /
UnimplementedError wording is baked into the header template — consistent
at gen time, not after fill.

## Expected

When `tdd func` (or any fill step) replaces a stub body with a dummy,
update or drop the honest-red claims in the header/doc comment so the file
describes the scaffolded-dummy state.

## Hard constraints

- Fix ONLY the header/doc comment rewrite in `func_command.dart` (and/or
  `behavior_test_writer.dart` stub template). Do NOT change the body fill
  logic, test generation, or state machine.
- Must not break contract trace preservation in the header.
- Must pass `dart analyze` with no new warnings.

## Assessment

- Verdict: valid
- Severity: medium (honesty-of-evidence bug: generated artifacts assert a
  state the file no longer has)
- Full analysis: `.specify/bugs/1517-func-stale-honest-red-header/assessment.md`
