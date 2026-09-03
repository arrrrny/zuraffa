feature: 071-zuraffa-agent-protocol (issue #809, branch spec/0809-zuraffa-agent-protocol)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: working tree at spec/0809-zuraffa-agent-protocol (base aad75c08) + this session's real runs
behaviors: 29
proven: 29
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 5
criteria_covered: 5
mutation_score: 3/3 # deliberate mutants, no mutation tool in profile (.specify/memory/tdd-profile.md); all caught, restoration verified byte-exact (cp of the pre-mutant file; analyze clean; suites re-green after each restore)
mutants_survived: 0
suite: fast tier chunked 69 chunks OK (64 chunks with tests, 5 SKIP-only), 2689 passed / 0 failed — includes the new test/zap chunk (+75/0); targeted: zap 75/75 per-file green; dart analyze 47 issues = pre-feature baseline 47 (zero new); dart format (Dart 3.13.1, CI's pinned SDK) --set-exit-if-changed lib test exit 0
method: /speckit.tdd.verify fallback (engine detection ZFA_MISSING — .zfa.json absent in this repo) — LLM-guided audit per the command file: cycle-log red evidence, git-history test-first ordering, rubric, deliberate-mutant mutation sampling, acceptance-criteria coverage; every number below is from a real run in this session

# TDD Verification: ZAP — Zuraffa Agent Protocol v0.1 (spec 071, issue #809)

**Verdict: PASS.** All 29 behaviors (8 acceptance + 21 unit) have recorded
red evidence appended through the real `CycleLog.append` writer (schema-1
hash chain), the git history shows the test-only commit preceding every
source commit, the full fast tier is green with the new `test/zap` chunk
included (2689 passed / 0 failed across 69 chunks), analysis is
byte-count-identical to the pre-feature baseline, the CI formatter gate
passes under CI's pinned SDK, and all three deliberate mutants were caught
— the second one ONLY by the independent foreign client, which is the
exact property issue #809's interop criterion exists to guarantee.

## Engine detection (the command file's Step 0)

```text
zfa --version   -> zfa v6.1.0     (OK)
test -f .zfa.json -> ZFA_MISSING
```

Per `.specify/extensions/tdd/commands/speckit.tdd.verify.md`, `ZFA_MISSING`
takes the documented **fallback path** (LLM-guided audit). This matches the
repo's own precedent: the most recent feature (066) and bug (tdd-133/939)
records were produced on the same path ("Mutation tool: none wired in CI"
per the profile — deliberate-mutant sampling per the rubric).

## Test-first evidence (red)

`dart test test/zap/` at the pre-implementation tree (2026-09-03, output
captured in-session):

```text
00:00 +0 -15: Some tests failed.
Failing tests:
  test/zap/zap_client_test.dart: loading test/zap/zap_client_test.dart
  test/zap/zap_command_smoke_test.dart: U20: …
  test/zap/zap_conformance_test.dart: A2: …
  … (+12 more)
  test/zap/zap_message_test.dart:12:8: Error: Error when reading
  'lib/src/zap/zap_chain.dart': No such file or directory
```

29 red entries recorded (`071-zap-A1…A8`, `071-zap-U1…U21`,
classification `loadError`, real per-file `dart test` commands with real
exit-1 outputs), appended through the real `CycleLog.append` writer by
`scripts/seed_cycle_log_071.dart` — the same machine format (schema-1
chain lines) the TDD pipeline writes. Git history corroborates the order:
the test-only commit (all of `test/zap/` + the red cycle-log) precedes the
protocol-library commit, which precedes the demo commit.

## Green evidence (this run — real numbers)

| Suite | Result |
|---|---|
| `test/zap/` (all 9 files, per-file runs) | **75 passed, 0 failed** (schema 11, validator 16, message 15, golden 2, host 19, client 1, conformance 6, smoke 2, interop 3) |
| `tools/run_tests_chunked.sh` (fast tier, disk protocol) | **69 chunks OK — 2689 passed, 0 failed** (64 chunks with tests, 5 skip-only), includes `test/zap` as its own chunk |
| `dart analyze` | **47 issues — byte-count identical to the pre-feature baseline** (`git stash -u` at `aad75c08`: 47). Zero new. `dart analyze lib/src/zap/ lib/src/commands/zap_command.dart`: No issues found. |
| `dart format --set-exit-if-changed lib test` (Dart **3.13.1**, CI's pinned SDK) | **exit 0** after formatting (see Finding 1) |

## Mutation results (deliberate-mutant sampling, one at a time)

| Mutant | Behavior | Survived | Caught by |
| --- | --- | --- | --- |
| `zap_host.dart` — the discipline check's red rule deleted (a `red` step exiting 0 no longer fails the receipt) | A8 / U18, FR-012 | **No** | `zap_host_test.dart` A8: "discipline violations flip the receipt verdict" (+red −1) — receipt verdict must be `fail` with `tdd-discipline ok:false` |
| `zap_chain.dart` — `fact['at']` dropped from the chain payload (the receipt no longer covers the certified timestamp) | FR-013, SC-003/4 | **No** | `zap_interop_test.dart` **A5 + A6** (+2 −2): the FOREIGN client's independent recomputation (per the published contract §5) disagrees with the host's `chainDigest` → `chainVerified:false` → exit 1. Notably: every shared-code test (host, reference client, conformance — 41 green) PASS under this mutant, because the reference client uses the same chain code. Only the independent implementation catches it — the two-implementation requirement is load-bearing, exactly as the issue argues |
| `zap_message.dart` — the version gate deleted (any `"zap"` version parsed as a half-understood message) | U10, FR-001 | **No** | `zap_message_test.dart` U10: "a wrong zap version throws with a version classification" (+red −1). (The host's own separate version gate kept A7 green — defense in depth, two layers, one pin per layer) |

Restoration verified after each mutant: byte-exact `cp` of the pre-mutant
file, `git status` clean for `lib/src/zap/`, analyze clean, suites re-green
(zap 75/75; interop 3/3).

## Rubric answers

1. **Tests first?** Yes — 29 red cycle-log entries with real commands and
   real failure output, appended before the implementation existed; the
   git history shows the test-only commit first (see commit sequence in
   the PR).
2. **Behavior asserted?** Yes — the pins assert the observable wire
   contract: error codes and `inReplyTo`, receipt verdicts and named
   checks, chain digests recomputed independently, exit codes, the CLI's
   machine summary line, real subprocess sessions over `zfa zap serve`.
   No doubles on the asserted paths: the scripted executor only replaces
   the OS process boundary (the protocol, not the subprocess, is the
   unit), and the interop tier runs REAL `dart bin/zfa.dart zap serve`
   processes with real `dart examples/zap_demo/tdd_loop.dart` executions.
3. **Would they catch a bug?** Yes — 3/3 deliberate mutants caught
   (table above), including one only catchable cross-implementation.
4. **Every requirement covered?** Yes — SC-001..SC-005 trace to A1..A6 +
   A7/A8 (below); FR-001..FR-017 trace through the U-rows in
   `tdd/test-list.md`.
5. **Worth keeping?** Yes — deterministic (no clocks/network asserted,
   temp dirs disposed), the protocol tier runs in seconds, the interop
   tier ~75s for three real subprocess sessions (the established
   `run_zfa_source`/MCP-demo e2e pattern), naming and layout mirror the
   suite they join.

## Success criteria — verified vs not

| SC | Verification | Status |
|----|--------------|--------|
| SC-001 published + machine-checkable contract | A1: committed `schemas/*.schema.json` + `golden/*.golden.json` byte-equal the code-derived maps; U12 goldens validate + round-trip; conform `--drift-dir` fails loudly on tamper (A3) | **VERIFIED** |
| SC-002 conformance suite passes for the reference client | A2: `zfa zap conform` exit 0, machine summary `zap: conform checks=N passed=N failed=0 — OK`; A3: `--format json` single verdict object; the suite's own reference session + discipline session included (U13/U18-shaped checks); SC-002 also carried by the in-CLI session checks | **VERIFIED** |
| SC-003 external non-MCP client drives a full TDD loop | A5: `dart examples/zap_demo/foreign_client.dart` exits 0 with `chainVerified:true`, receipt `verdict:pass`, `tdd-discipline ok`, 3 steps (red exit 1 witnessed → green exit 0 → verify exit 0), checkpoint save + restore — against a REAL `zfa zap serve` subprocess, zero zuraffa imports in the client | **VERIFIED** |
| SC-004 two independent implementations interop, zero code changes | A4 + A6: the reference `ZapClient` and the foreign client BOTH complete verified sessions against the SAME unmodified host command (`dart bin/zfa.dart zap serve` — asserted literally via `hostCommand` in both directions); receipts agree on the verdict vocabulary | **VERIFIED** |
| SC-005 hallucinated input structurally impossible | A7 + U4..U7 + U14 + U16: garbage lines, wrong version, direction violations, schema violations (with JSON-path details), budget/policy breaches rejected BEFORE execution; A8/U18: undisciplined loops executed but failed in the receipt | **VERIFIED** |

Issue #809 Done-when mapping:

- **"The conformance suite passes for the reference client"** — SC-002,
  A2/A3 (exit 0, every check green, reference session verified in-suite).
- **"Two independent implementations interop without code changes on
  either side"** — SC-004, A4/A6; strengthened by the mutant-2 result
  (the foreign client catches a contract drift the shared-code suite
  cannot see).

## Findings

| # | Severity | Finding | Evidence |
| --- | --- | --- | --- |
| 1 | LOW | Master at `aad75c08` fails the CI format gate itself: `dart format --set-exit-if-changed lib test` (Dart 3.13.1, from the repo root) changes 4 pre-existing files (`wire_command_test.dart`, `bug_937_reader_sections_test.dart`, `subject_signature_deriver.dart`, `test_list_reader.dart`) — the workflow's push trigger only covers `aster`/`main`, so the drift went unnoticed. This PR includes the pure-formatter cleanup of those 4 files (its own commit) so the gate is green; the changes are formatter output only, no semantic diff | gate output in-session: `Formatted 1582 files (4 changed) … exit 1` pre-cleanup, `exit 0` post-cleanup; `git diff` of the 4 files is reformat-only |
| 2 | LOW | The deterministic engine path (`zfa tdd verify`) was not taken: `.zfa.json` is absent in this repo, so `/speckit.tdd.verify`'s own engine detection routed to its documented fallback (the same path as features 066 and bug tdd-133/939). The fallback is the rubric-based audit above, with real runs and deliberate-mutant sampling | Step 0 output above (`ZFA_MISSING`) |
| 3 | LOW | CI's single-invocation `dart test test --exclude-tags flutter` was not run locally — per the disk protocol it is exactly the ~6.5 GB kernel-cache blowup the chunked runner exists to avoid; the chunked runner (69 chunks, 2689/0) is the same fast tier CI runs, one folder at a time, plus `dart analyze lib test --no-fatal-warnings` (47 = baseline). The interop tests spawn `dart` subprocesses which CI's ubuntu runner handles (the `run_zfa_source`/MCP-demo precedent) | dart_test.yaml header; chunked log `/tmp` capture |

No existing test was weakened, skipped, renamed out of a filter's reach,
or excluded by config in this change. The only edits outside the new
`lib/src/zap/`, `test/zap/`, `examples/zap_demo/`, and
`specs/071-zuraffa-agent-protocol/` trees are the one-line `ZapCommand`
registration in `cli_runner.dart` and the 4-file pre-existing formatter
cleanup (Finding 1).
