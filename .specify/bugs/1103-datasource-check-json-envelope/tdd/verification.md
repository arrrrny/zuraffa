# TDD verification — bug 1103 (datasource check `--json` envelope)

- **Feature/bug dir:** `.specify/bugs/1103-datasource-check-json-envelope/`
- **Branch:** `fix/1103-datasource-check-json-envelope`
- **Toolchain:** Dart SDK 3.13.3 (stable), Linux x64
- **Engine dispatch note:** `zfa --version` works (v6.1.0) but `.zfa.json`
  is absent from the repo, so per `speckit.tdd.verify` Step 0 the engine
  reports `ZFA_MISSING` and the fallback LLM-guided audit applies. Every
  claim below is backed by an actually executed command and its real
  output (nothing is projected or assumed).

## 1. Preflight — suite state

Fast-tier suite state at audit time (chunked runner semantics, one folder
per chunk, `--exclude-tags flutter`, stdin from `/dev/null`, kernel caches
cleaned between chunks — the `tools/run_tests_chunked.sh` protocol, sliced
over three sequential runs to fit the session tool timeouts):

| Suite | Result |
|---|---|
| bug repro folder `dart test test/plugins/datasource/ --exclude-tags flutter` | 31/31 passed |
| full fast suite, 82 chunks | **3175 passed / 2 failed**; 81/82 chunks fully green; 4 chunks skip (no fast-tier tests) |
| failing chunk | `test/plugins/cache` only — 2 failures, both **pre-existing on master** (see §6) |

`dart analyze`: 333 issues before and after the change — **identical
baseline** (40 error/warning, all pre-existing); zero issues in the two
touched files.

`dart format --output=none --set-exit-if-changed .`: 0 changed
(2201 files) — no remaining formatting diffs.

## 2. Test-first evidence

- The envelope tests were written and run against the UNFIXED tree before
  the fix existed: 6 failures, all `Could not find an option named
  "--json"` (RED evidence in `tdd/cycle-log.md`).
- Red/green discrimination was re-proven on the FINAL test code by
  `git stash push lib/src/commands/datasource_check_command.dart` → run →
  `+4 -6: Some tests failed` (6 × flag-unknown) → `git stash pop` → run →
  `+10: All tests passed!`.
- Commit layout: test + fix land in one commit on the bug branch; the
  cycle log is the test-first evidence record.

## 3. Red-phase evidence (what the tests catch)

Real CLI, unfixed tree (drift fixture):

```text
❌ Could not find an option named "--json".
```

and the human-only drift verdict the bug is about:

```text
❌ datasource check failed for `Product`: 1 parity divergence(s) ...
--> fix: implementation `ProductRemoteDataSource` is missing a method
declared in `ProductDataSource` — method `getList`, file
`lib/src/data/datasources/product/product_remote_datasource.dart` ...
```

Test-level (unfixed tree): 6 envelope assertions fail with the
flag-unknown usage exception; the pre-existing text assertions keep
passing, exactly matching the bug report ("no --json flag, no jsonEncode
envelope; emits --> fix: lines + exit code only").

## 4. Mutation check (real runs, each restored from backup afterwards)

| Mutant | Edit to `datasource_check_command.dart` | Result |
|---|---|---|
| A | verdict expression pinned: `'verdict': 'match'` | **KILLED** — `+5 -5: Some tests failed` (all drift-envelope assertions detect the lie) |
| B | `'schema': 1` → `'schema': 2` | **KILLED** — `+4 -6: Some tests failed` |
| C | `member` key dropped from `toFinding()` | **KILLED** — `+8 -2: Some tests failed` (finding-shape + member assertions) |

After each mutant the file was restored from a byte-identical backup
(`diff` clean) and the suite returned to `+10: All tests passed!`.

Mutants not pursued (recorded honestly):

- *exit-code flip (1 ↔ 0 on drift)*: covered by the same drift tests that
  kill Mutant A (`expect(exitCode, 1, ...)` on the `--json` runs), not
  separately executed.
- *re-adding prose to JSON mode*: killed by the machine-purity assertion
  `expect(output, isNot(contains('--> fix:')))` in T6; not separately
  executed as a mutant.

## 5. Test-smell rubric (new/extended tests)

- No conditional/skipped assertions; every envelope test decodes stdout
  with `jsonDecode` and asserts hard structural outcomes.
- No test reads another test's state; workspaces are per-test temp dirs
  deleted in `tearDown`; `exitCode` reset in both `setUp` paths and
  `tearDown`.
- The `--json` runs reuse each negative test's drift fixture, so text and
  envelope behavior are proven against the SAME drift, not parallel
  fixtures.
- Assertions target the contract (schema, verdict, findings kind/file/
  member/fix, exit codes, prose purity), not implementation details.
- No sleeps or scheduler timing anywhere in the new tests.

## 6. Pre-existing, out-of-scope observations (not caused by this branch)

- `test/plugins/cache/cache_adapter_receipt_test.dart` — 2 failures
  (`Expected: 'cache-adapter' / Actual: 'cache adapter'`; null spec
  binding). Reproduced identically on the UNFIXED baseline (`git stash` →
  run → exit 1, same 2 failures). Receipt-naming bug, unrelated to the
  datasource `--json` envelope. Hard constraint forbids fixing it here.
- `example/` subpackage cannot resolve (`flutter_test` unavailable — no
  Flutter SDK in this environment); out of scope, main package resolves
  and analyzes cleanly.

## 7. Acceptance-criteria coverage

| Acceptance criterion (issue #1103) | Evidence |
|---|---|
| `zfa datasource check Product --json` emits the envelope; test asserts schema, verdict, findings[*].kind | §3 RED → §1 GREEN; T5/T6 assert `schema == 1`, `verdict`, `findings[*].kind`; real-CLI envelope quoted in cycle-log |
| Drift path (`--> fix:`) still printed for humans when `--json` absent | all four extended negative tests keep the text assertions and pass; real-CLI no-flag run quoted in cycle-log |
| Sibling commands converge on the same envelope shape | integer `schema: 1` + `verdict` + `findings[]` mirrors `route verify` entity envelope and `state create` `schemaVersion = 1`; no-prose JSON mode mirrors `cache verify` |
| Exit codes stay (0 match / 1 drift) | asserted on every `--json` test (T5 exit 0, T1–T4/T6 exit 1); real-CLI runs show EXIT=1/EXIT=0 |
| Parity gate logic unchanged | detection loop untouched (only emission branches on `jsonMode`); all pre-existing parity/usage tests green |
| One PR for the bug | single branch `fix/1103-datasource-check-json-envelope`, single PR |
| `tdd/verification.md` real | this file; every result in it was actually executed |

## Verdict

**passed** — envelope tests are red on the unfixed tree and green on the
fixed tree, kill all three executed mutants, and the full fast chunked
suite is green except two failures pre-existing on master and documented
above.
