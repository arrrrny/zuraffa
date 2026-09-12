# Bug Fix: `zfa tdd func` reconciles the honest-red header/doc claims when it installs a dummy body

- **Slug**: 1517-func-stale-honest-red-header
- **Fixed**: 2026-09-11
- **Assessment**: ./assessment.md
- **Status**: applied
- **TDD artifacts**: tdd/test-list.md, tdd/verification.md (red → green → verify loop completed; see Deviations for the spec-kit note)

## Summary

When `zfa tdd func` installs a DUMMY body, it now rewrites the gen-time
honest-red claims in the stub header and doc comment so the file claims
the scaffolded-dummy state it actually contains ("Scaffolded dummy per
`zfa tdd func` (issue #1517) — replace this dummy body with the real
implementation") instead of the stale "honest red" / "Throws
[UnimplementedError] until the real implementation lands" from gen time.
Previously the fill step rewrote only the body (`raw.replaceRange` over
the matched stub declaration) and the header text survived verbatim,
contradicting the file content and producing honesty bugs in generated
evidence (caught by automated review of #1501; hand-corrected in commit
9960d905).

A still-red scaffold is deliberately EXEMPT: when the declared return is
a non-renderable entity, the installed body keeps
`throw UnimplementedError('implement per declared signature: …')` — there
the honest-red claims remain true and are preserved.

## Changes

| File | Change | Notes |
|------|--------|-------|
| `lib/src/plugins/tdd/commands/func_command.dart` | modified | `_run` gates on the installed body: `if (!scaffolded.contains('UnimplementedError')) updated = _reconcileHeaderClaimsForDummyBody(updated);` — the rewrite runs ONLY on dummy fills, never on still-red scaffolds. New private statics: `_dummyHeaderClaim` / `_dummyDocClaim` (the scaffolded-dummy claims), `_staleHeaderClaims` (the four gen-time claim sentences, consumed from `SubjectWriter`'s own `StubClaims` templates: legacy-unit header, acceptance header, contract-derived header, and the `Throws [UnimplementedError]` doc line), `_claimPattern` (matches a claim sentence across SubjectWriter's `// `/`/// ` line wraps), `_claimRegions` / `_reconcileClaimBlock` / `_reconcileHeaderClaimsForDummyBody` (scoped claim replacement with prefix-aware splicing, a residual-marker sweep, line-end whitespace trim, and a scaffolded-dummy note for claim-free headers). Body fill logic, test generation, state machine, receipt emission: untouched. |
| `lib/src/plugins/tdd/services/subject_writer.dart` | modified | The four honest-red claim sentences are hoisted into a shared `StubClaims` holder the templates interpolate; `func_command` consumes the same constants, so the writer and the reconciler cannot drift apart (review of #1523). |
| `test/plugins/tdd/commands/bug_1517_func_stale_honest_red_header_test.dart` | added | 5 tests: U-1517-1 (declared bool fill — the issue's exact U2 shape), U-1517-2 (legacy no-arg fill), U-1517-3 (still-red guard), U-1517-4 (acceptance-scenario variant, fixture rendered by `SubjectWriter`), U-1517-5 (hand-authored stub: its own note survives, fallback note inserted). |

## Review fixes (PR #1523)

The automated review of #1523 raised four still-valid points, all
addressed on top of the original fix:

- **Scoped reconciliation.** The rewrite (claim replacement, residual
  sweep, and fallback insertion) now runs only inside the generated
  comment blocks — the `// GENERATED STUB` header through its terminating
  `library;`, plus the declaration doc comment (`_claimRegions`). A
  hand-authored note elsewhere in the file, e.g.
  `// TODO: still throws UnimplementedError on the null path.`, is no
  longer deleted by the file-wide sweep (U-1517-5).
- **Format-clean splice.** A claim replaced mid-line (the contract-derived
  sentence) leaves the separator's space on the line it vacated; the
  block is now trimmed of line-end whitespace so the emitted subject
  stays `dart format --set-exit-if-changed` clean (asserted in U-1517-1).
  The bare `\n$replacement` fallback also defaults to a `// ` prefix.
- **Coverage.** Added the acceptance-scenario fixture (U-1517-4) and the
  claim-free hand-authored fixture (U-1517-5).
- **No prose duplication.** The claim sentences moved to
  `SubjectWriter`'s `StubClaims`; `func_command` consumes them.

## Contract trace preservation (constraint honored)

The rewrite never touches: `behavior_id:`, `source_criterion:`, the
description line, the declared-signature fence (`//     <signature>`),
the `Declared parameters:` line, `// ignore_for_file:`, imports, or any
code. The residual-marker sweep runs only inside the generated header and
declaration doc-comment blocks and explicitly exempts the trace-key lines
from its claim-marker drop, so a pathological description can never be
torn out of the header (nor can a hand-authored note elsewhere in the
file). U-1517-1 asserts every trace line byte-for-byte after the fill.

## Deviations from Assessment

- `specify init` / `specify extension add` were NOT re-run: the repo is
  already fully spec-kit initialized (`.specify/` with the `bug` and
  `tdd` extensions and 264 prior bug directories), and the standing
  warning forbids clobbering `.specify/templates` or `.specify/scripts`.
  The bug artifacts follow the extension's established house format.
- `behavior_test_writer.dart` was considered and ruled out during
  assessment (it writes the paired TEST files; the stale claims live in
  the SUBJECT stub header func itself rewrites) — the assessment's
  "and/or" scope collapses to `func_command.dart` alone.
