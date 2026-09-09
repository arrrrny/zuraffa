# TDD Test List — Spec 1334 zfa proof chain end-to-end validation

One behavior per line, traced to the acceptance scenarios / FRs in spec.md.
Every behavior is written as a failing test FIRST (RED), then made to pass
(GREEN). Red for this feature: pre-fix, `ProofChainChecker` and the
`proof chain` subcommand do not exist (compile error = red-protocol TODO,
re-run after skeleton).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | Verdict model: every JSON item carries category, severity, file, expected, actual, fix; drift item flips `ok` false and exit 1; gap-only keeps `ok` true and exit 0; infra sets exit 2; schema string is `proof-chain.v1` | FR-008 / FR-009 / US1-S3 | test/core/proof_chain_checker_test.dart |
| B2 | Clean project (no `.zfa/`, no `specs/`) → vacuous green: `ok` true, zero items, every check count 0, exit 0 | FR-009 / US1-S1 | test/core/proof_chain_checker_test.dart |
| B3 | Receipt digest drift: a receipted artifact edited after generation → `receipt_digest` drift with file, expected digest (receipt), actual digest (disk), fix naming the repro; deleted artifact → drift; matching artifact → no item | FR-002 / US1-S2 | test/core/proof_chain_checker_test.dart |
| B4 | CLI contract: clean project `zfa proof chain` exits 0; `--json` stdout is one `jsonDecode`-valid object with schema `proof-chain.v1`; drifted receipt exits 1; `.zfa/receipts` path occupied by a FILE (unlistable) exits 2 with a `--> fix:` line | FR-001 / FR-009 / US1-S1/S3/S4 | test/commands/proof_chain_command_test.dart |
| B5 | Behavior coverage: test-list behavior with a green cycle-log entry → no item; without green → `behavior_coverage` gap with fix `zfa tdd run <feature>`; green evidence whose `- test:` file is missing from disk → `test_integrity` drift | FR-003 / US2-S1/S2/S3 | test/core/proof_chain_checker_test.dart |
| B6 | Test integrity: registered test file missing from disk → `test_integrity` drift; registered test importing an absent file → `test_integrity` drift naming the unresolved URI; healthy registration → no item | FR-004 / US3-S1/S2 | test/core/proof_chain_checker_test.dart |
| B7 | `--run-tests`: injected runner returning exit 0 → no item; returning non-zero → `test_runtime` drift carrying the exit code and output tail; default (flag off) → info item "runtime not exercised", never a pass claim | FR-012 / US3-S3 | test/core/proof_chain_checker_test.dart |
| B8 | Route verify: `routes-<E>.json` + verify receipt `verdict.ok=false` → `route_verify` drift; verify receipt absent → `route_verify` gap with fix `zfa route verify <E>`; verify receipt input `verdict: skip` + reason → info, never drift | FR-005 / US4-S1/S2/S3 | test/core/proof_chain_checker_test.dart |
| B9 | Usecase verify: usecase-create receipt + healthy generated tree → no item; entity whose usecase files are drifted/missing → `usecase_verify` drift or gap; no usecase receipts → vacuous green | FR-006 / US4-S4 | test/core/proof_chain_checker_test.dart |
| B10 | Xray coverage: ui-ledger row whose prover has green evidence → traced (no item); row with no green prover → `xray_coverage` gap naming kind + surface; feature without ledger file → no items | FR-007 / US5-S1/S2/S3 | test/core/proof_chain_checker_test.dart |
| B11 | Read-only auditor: running `check()` over a seeded project leaves every input file's bytes and mtime unchanged | FR-011 / NFR-003 | test/core/proof_chain_checker_test.dart |
| B12 | Regression: existing `proof check` CLI tests and `ProofChecker` unit tests pass unchanged (the #807 surface is untouched); `zfa proof` help lists `check` and `chain` | FR-001 / tasks T008 | test/commands/proof_command_test.dart (existing, unchanged) |

## Red protocol

Run per file, never the full suite (disk ceiling):

```
dart test test/core/proof_chain_checker_test.dart          # B1-B3, B5-B11 (fast unit)
dart test test/commands/proof_chain_command_test.dart      # B4 (CLI subprocess, slow tier)
dart test test/commands/proof_command_test.dart            # B12 regression (existing file)
dart test test/core/proof_checker_test.dart               # B12 regression (existing file)
dart test test/core/proof/proof_check_valid_test.dart     # B12 regression (existing file)
```

Expected RED evidence (pre-implementation): B1-B11 fail to compile —
`proof_chain_checker.dart` and `proof_chain_command_test.dart` do not
exist; `zfa proof chain` is not a registered subcommand (B4: "Could not
find a subcommand named 'chain'"). B12 is expected GREEN at every phase
(the regression guard proves #807 is untouched).

## Green protocol

Post-implementation: every B1-B11 test passes in its file above; B12
stays green; `dart analyze` reports no new issues on changed files;
`dart run bin/zuraffa.dart proof chain` on a clean sandbox exits 0 and
`--json` decodes.
