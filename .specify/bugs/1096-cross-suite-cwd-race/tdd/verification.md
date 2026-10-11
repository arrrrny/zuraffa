# TDD verification — bug 1096 (cross-suite CWD race)

- **Feature/bug dir:** `.specify/bugs/1096-cross-suite-cwd-race/`
- **Branch:** `fix/1096-cross-suite-cwd-race`
- **Toolchain:** Dart SDK 3.13.3 (stable), Linux x64
- **Engine dispatch note:** `zfa tdd verify` requires a pinned feature
  (`spec.md` + `tdd/test-list.md` synthesized by `bug.fix` in TDD mode).
  This fix was driven directly on the bug branch, so per
  `speckit.tdd.verify` the fallback LLM-guided audit applies. Every claim
  below is backed by an actually executed command and its real output
  (nothing is projected or assumed).

## 1. Preflight — suite green

The audit refuses to run on a red suite. Fast-tier suite state at audit
time (chunked runner semantics, `--exclude-tags slow`/`flutter`):

| Suite | Command | Result |
|---|---|---|
| bug repro folder | `dart test test/plugins/service/` | 25/25 passed (×3 consecutive runs post-fix) |
| regression tests | `dart test test/commands/cli_runner_cwd_race_test.dart` | 2/2 passed (repeatedly) |
| regression home chunk | `dart test test/commands/ --exclude-tags slow` | 195/195 passed |

Full fast suite via `tools/run_tests_chunked.sh` + identical-semantics
resume of the remaining chunks (the runner has no native resume; per-chunk
command, `< /dev/null` and kernel-cache cleaning are identical): **84/84
chunks, 0 failures attributable to this branch**. Two knowns outside this
fix's scope are recorded in §6.

## 2. Test-first evidence

- The regression tests were written and run against the UNFIXED tree before
  the fix existed in the working tree; both failed (RED evidence in
  `tdd/cycle-log.md`).
- Red/green discrimination was re-proven after the final test edits by
  `git stash push lib/src/cli/cli_runner.dart` → run (2 failures) →
  `git stash pop` → run (2 passes).
- Commit layout: test + fix land in one commit on the bug branch; the
  cycle log is the test-first evidence record.

## 3. Red-phase evidence (what the tests catch)

Pre-fix run of `test/commands/cli_runner_cwd_race_test.dart`:

```text
Expected: not '/tmp/zfa_race_b_JWEAYF'
  Actual: '/tmp/zfa_race_b_JWEAYF'
suite B opened its chdir window while suite A was still inside its own —
the process-wide Directory.current race of issue #1096
```

and (cross-isolate, production topology):

```text
'round 0: artifact for RaceIsoXRound0 missing from own workspace (CWD race
 — write landed in another root). output head: {"schema":1,"ok":true,
 "file":"lib/src/domain/services/race_iso_x_round_0_service.dart",...}'
```

and the documented hazard, reproduced live in the first RED run:

```text
PathNotFoundException: Getting current working directory failed, path = ''
```

## 4. Mutation check (real run)

Mutant A — lock acquisition removed from `_withDirectory`
(`sed 's/    await _acquireCwdLock();/…removed/'`):

- Run: `dart test test/commands/cli_runner_cwd_race_test.dart`
- Result: **2/2 FAIL → mutant KILLED** (both tests detect the removed
  serialization).
- Restore fixed file → run → `00:00 +2: All tests passed!`

Mutants not pursued (recorded honestly):

- *release before restore*: racy-kill only (nondeterministic), not targeted
  by the deterministic probe; the release-after-restore ordering is
  guarded by B1's restored-CWD assertion probabilistically, not
  deterministically.
- *remove `nearestExistingDirectory`*: requires a concurrently deleted
  saved root to observe; cross-isolate timing dependent.

## 5. Test-smell rubric (new tests)

- No conditional/skipped assertions; both tests assert hard outcomes.
- No test reads another test's state; workspaces are per-test temp dirs
  with `finally` cleanup; pre-fix repo litter is cleaned by name-scoped
  teardown (`race_probe_*` / `race_iso_*` only).
- Deterministic arrangement: B1 forces the interleaving synchronously
  (no reliance on await topology or scheduler timing); B4 mirrors the real
  dart-test isolate topology and is deterministic-green post-fix.
- No sleeps-as-synchronization in assertions (the single 10 ms yield is
  part of arranging A's open window, asserted as a precondition).
- Assertions target the contract (no overlap, CWD restored, write
  isolation, verdicts ok), not implementation details.

## 6. Pre-existing, out-of-scope observations (not caused by this branch)

- `test/plugins/cache/cache_adapter_receipt_test.dart` — 2 failures
  (`Expected: 'cache-adapter' / Actual: 'cache adapter'`; null spec
  binding). Reproduced identically on the UNFIXED baseline
  (`git stash` → run → same 2 failures). Receipt naming bug, unrelated to
  CWD handling.
- `test/plugins/tdd/commands/compose_command_test.dart` U12 (symlink
  refusal) — failed once in ~4 chunk executions, passed 3/3 dedicated
  re-runs post-fix and passed in other chunk runs. It drives the CLI via
  `--project` (not `-C`), so the fix is not in its execution path;
  independent intermittent.

## 7. Acceptance-criteria coverage

| Acceptance criterion (issue #1096) | Evidence |
|---|---|
| Cross-isolate safe CWD handling in `CliRunner` | §4 mutant kill + B4 isolate test green |
| Service suite green with sibling suites | 25/25 ×3 post-fix (§1); B1–B3 green |
| Fix must not break parallel test execution for other suites | Lock taken only for `-C` windows; 84/84 chunks ran with default concurrency; non-`-C` suites never touch the lock |
| Red → green cycle | §2/§3 (RED) and §1 (GREEN), cycle-log records actual outputs |
| `tdd/verification.md` real | This file; every result in it was actually executed |

## Verdict

**passed** — regression tests kill the serialization mutant, are red on the
unfixed tree and green on the fixed tree; the bug's repro suite
(`test/plugins/service/`) is green 4× post-fix; the full fast chunked suite
is green except two pre-existing failures documented above.
