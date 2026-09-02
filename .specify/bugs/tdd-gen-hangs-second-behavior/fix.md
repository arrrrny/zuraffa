# Fix: tdd-gen-hangs-second-behavior (issue #744)

- **Fixed**: 2026-09-02 (this session)
- **Branch**: `fix/744-tdd-gen-hangs-second-behavior` (base: master `8c668955`)
- **Cycle**: red → green → verify (TDD, spec-kit TDD extension)

## Production change (1 file, per the bug's hard constraint)

`lib/src/plugins/tdd/commands/gen_command.dart` — the gen step only:

1. **Bounded flow (the #742 timeout pattern applied to gen as a safety net).**
   The whole flow — behavior resolution, ownership preflight, the two
   writer writes, the registry append, and the staleness re-render — now
   runs under ONE wall-clock budget (`--timeout <seconds>`, default 30s —
   the same acceptance budget the #744 records name: "A2 completes within
   30s"). A stage that waits indefinitely — the recorded failure mode
   ("hangs indefinitely … killed with SIGKILL") — stops at the budget with
   an honest misfire-stop classification naming behavior, step, and
   `outcome=timeout`, and a non-zero exit, instead of hanging until the
   operator kills it. gen spawns no subprocess of its own, so the budget
   needs no process-kill side effects; a timed-out stage's pending I/O is
   abandoned as the process exits.
2. **Deferred-predecessor deadlock inspection (the #738-era concern).**
   The flow's only awaited stages are file I/O on the test-list row, the
   registry, and the pair on disk — it never reads run-state, never runs
   the suite, and holds no cross-behavior wait, so a predecessor deferred
   at its phase-2 make (A1 unexpressible, bug #625/#657) cannot block a
   later gen (A2). The inspection is pinned by a regression test: gen A2
   with A1's red stub on disk completes well inside the 30s budget with
   A1's artifacts untouched. The budget additionally caps whatever could
   stall, so the recorded hang is structurally impossible to reach now.

`services/runner.dart`, `commands/make_command.dart`, and every other file:
untouched — the #731/#737 regression-verdict logic in make's suite guard is
not re-plumbed here, so the false-positive fix from #738 stands unchanged.

## Tests (test/plugins/tdd/commands/gen_command_test.dart, 3 new)

1. `a stalled gen stage cannot hang the command past the default budget —
   it stops with outcome=timeout instead of hanging until SIGKILL` — the
   test list is replaced with a POSIX FIFO no writer ever opens, so the
   flow's FIRST awaited stage stalls forever: the deterministic stand-in
   for the recorded indefinite wait. Pre-fix the command hung until the
   test's own 60s watchdog killed it (RED, the recorded behavior);
   post-fix it stops at the 30s budget with the full classification
   (behavior, step, outcome) and a non-zero exit.
2. `an explicit --timeout overrides the default budget and is honored` —
   `--timeout 3` on the same stalled fixture returns in ~3s with the same
   classification (the budget is real, not a fixed constant).
3. `gen A2 on a fresh project completes within the 30s budget with A1
   deferred (red stub on disk) — no deferred-predecessor deadlock` — the
   recorded repro shape (A1 generated, its stub red; then gen A2): A2
   completes with `created/created` ownership, A1's artifacts untouched.
   Passed against the pre-fix code too — that is the deadlock
   inspection's honest result: no cross-behavior wait exists in the
   direct flow, and this test pins the guarantee.

All three run in the `slow` tier (the file's existing tag); tests 1–2 are
POSIX-guarded (`mkfifo`), skipped on Windows.

## Verification summary (real runs, this session)

- RED (pre-fix): tests 1–2 failed — test 1 hung the full 60s watchdog and
  was killed (the recorded SIGKILL mode), test 2 failed on the missing
  `--timeout` option; test 3 passed pre-fix (guard).
- GREEN (post-fix): `dart test --preset=all test/plugins/tdd/commands/
  gen_command_test.dart` → `+16` — all 16 passed (13 pre-existing + 3 new).
- `dart analyze` → No issues found. `dart format --set-exit-if-changed
  lib test` (the CI gate) → 0 changed, exit 0. `git diff --stat` → the
  fix + its tests only, insertions only.
- Fast suite, chunked (official chunk list, 68 chunks, kernel caches
  cleared between chunks per tools/run_tests_chunked.sh) → 66 passed,
  2 skipped (no fast-tier tests: test/property, test/integration),
  **0 failed** — no new failures.
- Deliberate mutants (manual, restored after each, suite re-run):
  M1 budget enforcement removed → CAUGHT (test 1 hung → watchdog kill);
  M2 outcome field dropped from the classification → CAUGHT
  (`Expected: contains 'outcome=timeout'`); M3 `--timeout` override
  ignored → CAUGHT (test 2 elapsed bound). Score 3/3.
- Details and audit verdict: `./tdd/verification.md`.

Closes #744
