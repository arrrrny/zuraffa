---
feature: tdd-doctor-feature-positional
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md # rubric graded against
verified_at: fix/tdd-doctor-feature-positional
behaviors: 6
proven: 6
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: sampled # no mutation tool wired (tdd-profile.md Phase 4 fallback); 2 deliberate mutants, both killed
mutants_survived: 0
suite: bug_828_cycle_log_evidence_integrity_test.dart 14/14 (incl. the four previously usage-error tests); sibling doctor surface swept — 11 failures identical on pristine origin/master (175f990d), i.e. pre-existing, none in the changed surface; dart analyze exit 0 (No issues found); dart format 0 changed. macOS / Dart 3.13.x, 2026-09-13.
---

# TDD Verification: tdd-doctor-feature-positional (#1585)

**Verdict: PASS.** The suite's `doctor()` helper now invokes
`zfa tdd doctor <feature> --project <root>` — the positional form
`DoctorCommand` declares — so the four tests that died on the usage error
exercise the real drift logic. Two defects the usage error had masked are
fixed with their pins: the doctor's evidence hash-chain walk (restored after
the `b6afda42` #840 rework dropped it, still documented as the doctor's job
in `cycle_log.dart`) and the consistent-store zero-drift pin (moved from the
retired `drifts=<n>` summary line to the verdict envelope).

## What the run proved (fresh, this branch)

1. **RED was honest** (`tdd/cycle-log.md`): the issue's exact repro —
   `dart test --preset=all …/bug_828_…_test.dart` → `02:38 +9 -4`, the
   captured output being the `Could not find an option named "--feature"`
   usage text. With only the helper fixed, the suite moved to `+11 -2` and
   the two real disagreements surfaced (tampered chain read as
   `stores agree — no drift detected`; `contains('drifts=0')` no longer
   produced by any code path).
2. **GREEN is real**: the full file on the fixed tree →
   `04:57 +14: All tests passed!` — the 13 pre-existing behaviors plus the
   new linkage pin (U1585-6).
3. **Mutation sampling** (no mutation tool wired per `tdd-profile.md`; two
   deliberate mutants, applied one at a time and reverted):
   - **M1 — the whole gate disabled** (`chainDrifts = <String>[]`) →
     **killed by both hash pins** (`--plain-name "hash chain"` → 2 failures,
     both `Expected: <1> / Actual: <0>`).
   - **M2 — the linkage arm dropped** (`if (false && entry.prevHash != prev)`)
     → **killed by U1585-6** (`Expected: <1> / Actual: <0>` + `stores agree —
     no drift detected`); the content arm alone cannot see a severed
     `- prev-hash:` because the walk's local `prev` is still `genesis`.
     U1585-6 was added *because* this sampling showed the linkage arm had no
     pin — a content-only walk survived before it.
   - Both mutants reverted; the restored tree re-ran green (`+14`) and the
     diff matches the intended fix (`doctor_command.dart` +100,
     `bug_828_…_test.dart` +12/-2 minus the new pin's 34 lines).
4. **No collateral damage** — the sibling doctor surface was swept
   (`bug_1495`, `bug_911`, `bug_1331`, `bug_969`, `bug_1324`, `bug_1345`,
   `bug_1264`, `bug_840`, `bug_874`, `bug_1397`, `bug_1573`,
   `run_command_bug_1471`, `bug_912`, `issue_1423`). The sweep reports 11
   failures; **the same 11 fail on pristine `origin/master` (175f990d) in a
   clean worktree with the identical count (`+28 -11`)** — they are
   pre-existing slow-tier reds in `gen`/`reset`/`run`/`migrate-paths`
   assertions, not reachable from the changed surface. Every
   doctor-invoking test in those files passes, including the `bug_969`
   doctor envelope case and the `bug_1423` doctor hand-delta case.
5. **Static hygiene**: `dart analyze` on both changed Dart files →
   `No issues found!`; `dart format` on both → `0 changed`.
6. **Constraint compliance**: `git status` touches exactly
   `lib/src/plugins/tdd/commands/doctor_command.dart` (one restored gate +
   one private walk + the header contract entry) and
   `test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart` (helper
   form, envelope pin, new linkage pin), plus the `.specify/bugs/<slug>/`
   artifacts. No other lib behavior changed.

## Criteria coverage

| Criterion | Evidence |
| --- | --- |
| FR-001 — the helper uses the form the command declares | U1585-1 (red→green: pre-fix `+9 -4` usage text; post-fix the verdict is reached) |
| FR-002 — the four masked tests pass, the rest stay green | U1585-2 (14/14) |
| FR-003 — the doctor recomputes the chain and reports mismatch as drift | U1585-3 (content arm, red pre-restore), U1585-6 (linkage arm, killed M2), U1585-4 (legacy hash-less entries tolerated) |
| FR-004 — the zero-drift pin reads the verdict envelope | U1585-5 (healthy + empty `drifts`, exit 0) |

## Test-quality notes

- Every pin asserts the command's public contract (exit code, drift wording,
  `--> fix:` line, envelope fields) — never internal paths or private state.
- The tamper fixtures use the real `CycleLog` writer, so the pins hash the
  same canonical payload the production writer does
  (`CycleLog.payloadFromFields`), the same one `replay_history.verifyIntegrity`
  recomputes.
- No sleeps, no randomness, no conditional assertions in the new/updated test
  bodies (`high_smells: 0`).

## Residual risks and out of scope

- The suite is `@Tags(['slow'])`: only `--preset=all` runs it, which is how
  the three-way drift survived. Nothing here changes that lane.
- The 11 pre-existing sibling failures are real reds on master (identical on
  base) and are **not** addressed by this fix; they belong to their own
  triage.
- The `--repair` GC path and the other doctor gates were not touched.
