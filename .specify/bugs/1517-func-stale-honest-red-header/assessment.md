# Bug Assessment — #1517: `zfa tdd func` fills the dummy body but keeps the honest-red header claims

- **Slug**: 1517-func-stale-honest-red-header
- **Created**: 2026-09-11
- **Source**: https://github.com/arrrrny/zuraffa/issues/1517
- **Verdict**: valid
- **Severity**: medium (honesty-of-evidence bug; no crash, no wrong code, wrong *claims*)

## Report (verbatim, condensed)

> `zfa tdd func` fills a declared stub's body (e.g. `return true;` for a
> bool) but preserves the generated stub header and doc comment verbatim.
> The surviving text still claims "honest red" / "Throws
> [UnimplementedError]" — now false: the paired test compiles and goes
> green on the dummy body alone.

Reproduction (from PR #1501, fixture 004-login-ui, U2):

1. `zfa tdd gen U2` emits `u2_subject.dart` with header: "This is a MINIMAL
   COMPILABLE STUB: it does NOT satisfy the behavior — the paired test
   fails on first execution (honest red)." and doc: "Throws
   [UnimplementedError] until the real implementation lands."
2. `zfa tdd func U2` rewrites the body to `return true;` per
   `isSubmittable(String email, String password) -> bool`.
3. Header and doc unchanged — the committed file claims red while the
   suite is green (+1 passed, body `return true;`).

Caught by automated review of #1501; the stale text had to be
hand-corrected in commit 9960d905.

## Root cause (confirmed against the tree)

`FuncCommand._run`
(`lib/src/plugins/tdd/commands/func_command.dart`) splices the scaffolded
body with `raw.replaceRange(stub.start, stub.end, scaffolded)` — the
replacement range covers ONLY the matched stub declaration
(`_stubSignature`), so the gen-time header block comment and the doc
comment above it survive byte-for-byte. The honest-red / UnimplementedError
wording is baked into those comments by `SubjectWriter`
(`_renderContractUnitSubject`, the legacy unit template and the acceptance
template) — consistent at gen time, stale after any dummy fill.

Design tension (kept intact by the fix): func deliberately preserves the
header's contract traces (`behavior_id`, `source_criterion`, description,
declared-signature fence, `Declared parameters:`) — spec 0806 FR-006 even
relies on the doc comment *mentioning* `UnimplementedError` without
carrying a real throw (the refusal keys on the actual statement, not the
word). So the fix cannot be "drop the header"; it must rewrite the claim
sentences only.

## Expected

When `tdd func` (or any fill step) replaces a stub body with a dummy,
update or drop the honest-red claims in the header/doc comment so the file
describes the scaffolded-dummy state.

## Hard constraints (from the bug brief)

- Fix ONLY the header/doc comment rewrite in `func_command.dart` (and/or
  `behavior_test_writer.dart` stub template). Do NOT change the body fill
  logic, test generation, or state machine.
- Must not break contract trace preservation in the header.
- Must pass `dart analyze` with no new warnings.

## Scope decisions

- `behavior_test_writer.dart` is NOT touched: it writes the *paired test*
  files; the stale claims live in the *subject stub* header that func
  itself rewrites. The fix surface is `func_command.dart` alone.
- The still-red scaffold path (a non-renderable declared return keeps
  `throw UnimplementedError('implement per declared signature: …')`) is
  explicitly EXEMPT from the rewrite: there the honest-red claims remain
  true. The rewrite is gated on the installed body being a dummy.
- `make_command.dart` has its own fill path with the same class of stale
  prose; it is OUT OF SCOPE for this bug (one PR per bug, func surface
  only).

## Remediation

`func_command.dart` gains `_reconcileHeaderClaimsForDummyBody`: when the
scaffolded body contains no `UnimplementedError` (i.e. a dummy was
installed), the four gen-time claim sentences (legacy-unit, acceptance,
contract-derived header claims + the `Throws [UnimplementedError]` doc
line) are replaced with scaffolded-dummy claims; a safety net drops any
residual claim-marker comment line (trace lines exempt); a claim-free
header still receives a one-line scaffolded-dummy note. Traces are never
rewritten.
