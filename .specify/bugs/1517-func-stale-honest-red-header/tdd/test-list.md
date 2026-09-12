# Test List: bug #1517 — func fill reconciles the honest-red header claims

Traces: GitHub issue #1517 · assessment in this directory · hard
constraints: fix ONLY the header/doc comment rewrite in
`func_command.dart`; body fill logic, test generation and state machine
unchanged; contract trace preservation must not break; `dart analyze` with
no new warnings.

- feature: 1517-func-stale-honest-red-header
- source: issue.md (Expected section) + PR #1501 review finding (commit
  9960d905 hand-correction)
- suite tier: fast
  (`dart test test/plugins/tdd/commands/bug_1517_func_stale_honest_red_header_test.dart`)

## Behaviors

| id | behavior | serves | test | state |
| -- | -------- | ------ | ---- | ----- |
| B1 | After `zfa tdd func` fills a declared bool stub (`isSubmittable(String email, String password) -> bool`) with `return true;`, the subject header/doc comment no longer claim honest red / UnimplementedError — they carry the scaffolded-dummy state claim — while `behavior_id`, `source_criterion`, the description, the declared-signature fence and the `Declared parameters:` trace lines survive verbatim | issue Expected section ("update or drop the honest-red claims … so the file describes the scaffolded-dummy state") | `test/plugins/tdd/commands/bug_1517_func_stale_honest_red_header_test.dart` → `U-1517-1` | green |
| B2 | After func fills a LEGACY no-arg unit stub (undeclared behavior, prose-derived dummy), the legacy honest-red header sentences and the `Throws [UnimplementedError]` doc line are reconciled the same way, with the header traces preserved | same, legacy template variant | same file → `U-1517-2` | green |
| B3 | A still-red scaffold (non-renderable declared return keeps `throw UnimplementedError('implement per declared signature: …')`) keeps its honest-red claims — they remain true; func must not strip them | constraint "claims match actual state" cuts both ways | same file → `U-1517-3` | green |

## Regression surface guarded by pre-existing tests

- `test/plugins/tdd/commands/func_command_test.dart` (U-F1..U-F9) — the
  fill contract: derived shapes, idempotency, refusals, test-file
  ownership, surrounding-source preservation.
- `test/plugins/tdd/commands/func_convergent_test.dart` (U7/U7b) — the
  already-implemented fixed point (file untouched byte-for-byte) and the
  unrecognized-throw refusals.
- `test/plugins/tdd/commands/func_declared_signature_test.dart` — the
  declared signature outranks prose inference (#920/#1259).
- `test/plugins/tdd/scenarios/sc_017` / `sc_018` — the real pipeline's
  gen→func pair (the doc-comment-remains tolerance of bug #718 is
  superseded by #1517's reconciliation for the func surface; the
  `throw UnimplementedError` absence assertion is unchanged).
