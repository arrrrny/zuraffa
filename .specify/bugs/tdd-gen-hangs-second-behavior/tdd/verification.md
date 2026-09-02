feature: .specify/bugs/tdd-gen-hangs-second-behavior (bug #744, pinned per bug extension TDD mode)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 8c668955 (branch fix/744-tdd-gen-hangs-second-behavior, fix uncommitted at audit time)
behaviors: 3
proven: 3
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 2
criteria_covered: 2
mutation_score: 3/3 caught # scope: gen_command.dart bounded-flow guard only, manual deliberate mutants
mutants_survived: 0
suite: "gen_command_test.dart +16 (13 pre-existing + 3 new, --preset=all); chunked fast suite: 66 passed / 2 skipped / 0 failed (68 chunks); dart analyze: clean; dart format (CI gate: lib test): 0 changed"
---

# TDD Verification: bug #744 — zfa tdd gen hangs on second behavior

**Verdict: PASS_WITH_GAPS.** The red→green cycle is real and was executed in
this session against the real CLI surface (`CliRunner.runCapturing` →
`GenCommand.run`, plus an end-to-end AOT-binary check): the two new timeout
tests failed against the pre-fix code with the recorded #744 signature (an
indefinite stall killed by a watchdog), and pass against the fix with the
`outcome=timeout` misfire-stop. The recorded acceptance criteria are both
covered ("gen A2 on a fresh project completes within 30s"; "A1
deferred/unexpressible + A2 gen does not deadlock"). No existing test was
weakened (the diff is insertions-only on the test file). The gaps are
disclosed below: the stall trigger could not be reproduced from the recorded
scenario on this tree (finding 1), and the new tests join the `slow` tier so
the default fast CI tier does not execute them (finding 2).

## Reproduction audit (what the RED actually proved)

The assessment's hypothesis ("gen's regression check spawns a `dart test`
subprocess with no timeout") was checked directly: gen_command.dart's full
transitive call graph (TestListReader → ArtifactRegistry.preflight →
BehaviorTestWriter/SubjectWriter → ArtifactRegistry.append →
_regenerateStaleStub) spawns no subprocess and contains no unbounded loop;
fix #738 (commit 0f8ac301) touched make_command.dart, not gen_command.dart.
The direct repro (`gen A1` then `gen A2` on a fresh project) was executed via
JIT `dart run`, via the AOT-compiled binary, across dry-run/no-`--feature`/
unit-id/repeat variants, and through the `zfa tdd run` driver — no hang on
this tree in any variant. The RED therefore reproduces the recorded FAILURE
MODE, not the reporter's exact trigger: a POSIX FIFO substituted for the
test-list makes the flow's first awaited stage wait forever, which is
deterministically the "hangs indefinitely, killed with SIGKILL" behavior the
issue records. The fix (a wall-clock budget on the whole flow, per the
assessment's own remediation: "the timeout should be applied here as a
safety net regardless of the root cause") bounds that mode — and any other —
so the recorded symptom is structurally unreachable. The un-reproduced
original trigger is finding 1.

## Test-first evidence

| Behavior | Class  | Evidence |
| -------- | ------ | -------- |
| B1 — a stalled gen stage stops at the budget with an honest classification instead of hanging | PROVEN | RED captured in-session (pre-fix run): test hung until the 60s watchdog killed it (`00:60 +0 -1`, the recorded SIGKILL mode) and had no `--timeout` to honor; GREEN post-fix: stops at 30s with `zfa tdd gen: timeout after 30s — behavior=A1 step=gen outcome=timeout`, non-zero exit. The test file and the fix land in one atomic commit, so git history alone shows LIKELY ordering; the session's RED run (logged before the fix was written) upgrades it to PROVEN per the #731 precedent's convention. |
| B2 — an explicit `--timeout` overrides the default budget | PROVEN | RED (pre-fix): `Could not find an option named "--timeout"` (option absent). GREEN post-fix: `--timeout 3` returns in ~3s with the same classification. |
| B3 — A1 deferred/unexpressible + gen A2 completes with no deadlock | PROVEN (guard) | Passed against the PRE-FIX code — the deadlock inspection's honest result (no cross-behavior wait exists in the direct flow). Pins the guarantee: A2 completes `created/created` within the 30s bound, A1's artifacts byte-untouched. |

No existing test was modified (`git diff` on the test file shows insertions
only, `+115 −0`), so the rubric's weakened-existing-test check is clean.

## Acceptance-criteria coverage (from the committed assessment)

| Criterion | Covered by | How |
| --------- | ---------- | --- |
| "zfa tdd gen A2 on a fresh project completes within 30s (not hangs)" | B1 + B3 | B3 runs the recorded repro shape end-to-end inside the 30s wall; B1 proves the budget stops the exact stall mode. Real-CLI corroboration: AOT binary on a stalled list exits 1 in 5s with `--timeout 5` (`❌ Error: Bad state: zfa tdd gen: timeout after 5s — behavior=A2 step=gen outcome=timeout`). |
| "A1 (unexpressible/deferred) + A2 (gen) does not deadlock" | B3 | Two-row fixture, A1 materialized (red stub on disk, the driver's post-deferral state), A2 completes, A1 untouched. |
| "do not reintroduce the #731/#737 false-positive" | diff scope | The fix touches gen_command.dart only; make's suite-guard verdict (`_regressionsAttributableToThisMake`) is byte-untouched, and the full chunked fast suite is green — the #731 regression tests inside `make_command_test.dart` pass unmodified in the `test/plugins/tdd/commands` chunk. |

## Test-smell audit (rubric catalogue)

- **Assertion-free / double-configured**: none — every new test asserts
  observable CLI output (the six-field contract, the classification line)
  or on-disk artifacts, through the real command dispatch, not a mock.
- **Conditional test logic / hidden control flow**: the `Platform.isWindows`
  early-return in B1/B2 is an environment guard for the `mkfifo` fixture
  (documented in the test body), not silent skipping of the assertion.
- **Time-bomb / sleep-based sync**: none — no `sleep`s; bounds are budgets
  with watchdogs strictly larger (60s watchdog around a 30s budget; 30s
  watchdog around a 3s budget).
- **Maintenance burden**: the FIFO fixture is 3 lines and POSIX-portable
  (macOS + Linux, the repo's real surfaces); Windows skips honestly.
- **Pre-existing smells in the file** (uncaptured by this fix, not
  introduced by it): the honest-red and acceptance tests shell out to real
  `dart test` with 2–3 minute timeouts — slow but load-bearing; unchanged.

## Mutation results (deliberate mutants, manual — no mutation tool in profile)

Scope: the bounded-flow guard in `gen_command.dart` only (the file the fix
changed). Every mutant was restored byte-exactly and the file re-analyzed
clean after the restore.

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| M1 — budget enforcement removed (`.timeout(budget)` → no-op) | B1 | No | CAUGHT: test 1 hung until its 60s watchdog killed it — the mutant re-creates the original bug, the test owns it |
| M2 — `outcome=timeout` field dropped from the misfire classification | B1, B2 | No | CAUGHT at 30s: `Expected: contains 'outcome=timeout' / Which: does not contain` — the classification is load-bearing |
| M3 — `--timeout` override ignored (`parsed` pinned to the default) | B2 | No | CAUGHT at 30s: the 3s run exceeded its elapsed bound / watchdog — the flag is real |

Score: 3/3 caught, 0 survived.

## Findings

| # | Severity | Finding | Evidence / disposition |
| - | -------- | ------- | ---------------------- |
| 1 | MED | The reporter's exact hang trigger could not be reproduced on this tree from the recorded repro (direct gen path, JIT + AOT, driver included) — the RED uses a deterministic stand-in for the recorded stall mode instead. The hang may require the reporter's environment (macOS + globally-activated v6.1.0 binary + Flutter-SDK project state) or may have involved a step spawn adjacent to gen (runSingle/runSuite in `runner.dart` still carry the #742 no-timeout gap, outside this bug's single-file constraint). | Session repro matrix: JIT gen A1/A2 OK (16s each); AOT gen A1/A2 OK (12ms each); sweep S1–S5 OK; run driver progressed past A2's deferral into U1/U2 spawns (no hard hang; per-step `dart run` JIT cost ~15s makes the driver slow but bounded-progress on this box) |
| 2 | LOW | The three new tests live in the `slow` tier (the file's pre-existing `@Tags(['slow'])`), so the default fast CI tier (`dart test`) does not execute them; they run under `--preset=all` and the `test/plugins/tdd/commands` slow chunk. Consistent with the file's existing convention, but the fast tier will not catch a regression of this guard. | `dart_test.yaml` `exclude_tags: slow`; file tag header |
| 3 | LOW | The budget defaults to 30s, tuned to the acceptance wording; a pathological giant project (huge specs tree) could legitimately exceed it and would now stop with `outcome=timeout` instead of completing. Mitigation already shipped: `--timeout <seconds>` override, and the stop names the budget and the remediation. | gen_command.dart `--timeout` help text; misfire message |

## Verified commands (this session, real runs)

- RED: `dart test --preset=all --concurrency=1
  test/plugins/tdd/commands/gen_command_test.dart --plain-name 'bounded gen
  flow'` → pre-fix `+0 -3` (test 1: watchdog kill at 60s — the recorded
  mode; test 2: option missing; test 3 passed — guard, pre-fix).
- GREEN: `dart test --preset=all --concurrency=1
  test/plugins/tdd/commands/gen_command_test.dart` → `+16` all passed.
- Fast suite: official 68-chunk list (official script semantics: per-chunk
  `dart test <dir> --exclude-tags flutter`, kernel caches cleared between
  chunks) → 66 passed / 2 skipped (no fast-tier tests) / **0 failed**.
- `dart analyze` → No issues found (full package).
- `dart format --set-exit-if-changed lib test` → 0 changed, exit 0 (the CI
  format gate's exact scope); `git diff --stat` → the fix + its tests only,
  insertions only.
- Mutants M1–M3 → all caught, all restored, analyze clean after restore.
- Real-CLI corroboration: `dart compile exe bin/zfa.dart` → stalled-list run
  exits 1 in 5s with the full classification; `--timeout notanumber` →
  usage error; `--help` documents the flag.
