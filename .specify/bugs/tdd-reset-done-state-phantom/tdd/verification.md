feature: tdd-reset-done-state-phantom (issue #1264, slug tdd-reset-done-state-phantom)
verdict: PASS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: working tree at d3679e0f (master) + fix/1264-tdd-reset-done-state-phantom
behaviors: 5
proven: 5
likely: 0
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 4
criteria_covered: 4
mutation_score: n/a # see provenance note — zfa tdd verify not dispatchable in this environment (ZFA_MISSING); test strength evidenced by the deliberate pre-fix RED run (every pin failed for the right reason against the exact bug state) instead of mutation sampling
mutants_survived: 0
suite: new pins 5/5 (bug_1264_reset_done_state_phantom_test); touched suites all green on the fix HEAD: run_command_test 49/49 (bug-682 bootstrap intact), unified_journal_commands_test 12/12, commands/run_engine_command_test + commands/run_skin_command_test 17/17, tdd_command_smoke_test + bug_911 11/11; baseline-identical on this machine: bug_840_recovery_commands +4/-5, two_cycle + bug_828 +28/-4, bug_874 + bug_969 + explain +47/-4 (every failure reproduced identically on the stashed pre-fix tree — pre-existing environment failures, none introduced); analyze on changed files: No issues found; `dart format --set-exit-if-changed lib/ <new test>` exit 0

# TDD Verification — tdd-reset-done-state-phantom (#1264)

**Verdict: PASS.** The issue's exact phantom (reset → doctor `healthy` →
run `2 already done — skipping` → status `engine ✅ 2/2` on nonexistent
tests) is reproduced red by five new pins against the real CLI, and fixed
green by the minimal remediation the assessment prescribes: reset
tombstones the dropped behaviors in the append-only journal (a), the run
driver refuses to honor tombstoned evidence and re-drives the dropped
behaviors from gen (b), doctor grows the store-to-tree check and reports
`evidence-without-artifact` with exactly one recovery (c), and status
demotes a lane receipt whose behaviors have no backing test file (d).

## Provenance note (honest constraints)

- `.specify/bugs/tdd-reset-done-state-phantom/issue.md` and `assessment.md`
  were NOT committed in the repo (the task brief said they were; they do
  not exist at HEAD). They were materialized verbatim from the live
  GitHub issue #1264 (fetched via the API) plus the task brief's
  remediation text — no synthetic re-triage was invented.
- `zfa tdd verify` was not dispatchable: no global `zfa` binary and no
  `.zfa.json` in the repo root → the speckit.tdd.verify Step-0 probe
  returns `ZFA_MISSING`, so per that command's documented fallback path
  this audit was produced by the LLM-guided process with the real
  red/green evidence recorded in `tdd/cycle-log.md` (same precedent as
  the accepted bug-1181 verification).
- The Spec Kit TDD extension is already present and enabled at v1.1.2
  (`.specify/extensions.yml` lists `tdd`; `specify extension list` would
  show "✓ TDD Extension"); re-running `specify init` / `extension add`
  was skipped as a no-op-by-configuration that risked clobbering
  project-specific `.specify/templates` / `.specify/scripts`
  customizations, exactly as the task brief warns.
- Toolchain: Dart SDK 3.13.3 stable, linux-x64 (task requires Dart
  3.13+). Flutter is not installed; the touched suites are all
  fast/vm-tier and none require it. Kernel cache cleaned
  (`.dart_tool/test/`, `dart_test.kernel.*`) before/after every chunk per
  the cloud-agent protocol; disk stayed >80% free throughout.
- The `pubspec.yaml` has no `dependency_overrides:` section to delete —
  the repo removed it intentionally (the in-file comment pins the reason);
  `dart pub get` resolved everything from pub.dev.

## What was actually wrong (root cause, proved from the RED run)

`zfa tdd reset` deletes exactly its owned files (registry test/subject
pairs), `tdd/artifacts.json`, and `tdd/run-state.json` — and correctly
never touches the append-only evidence (`tdd/cycle-log.md`,
`tdd/journal.json`). The run driver then reconciles state from evidence
(FR-003, the bug-682 bootstrap): `pending + red+green evidence → done`,
with no store-to-tree check — so every behavior whose artifacts reset just
dropped re-derives `done` from the evidence that outlived them, and the
driver skips it (`already done — skipping`) before `hasGenArtifacts` could
ever demote the entry. Doctor's checks are all store-to-store: with the
registry and run-state gone there is no claim left to contradict the
surviving evidence, so it reports `healthy`. Status reads the lane
receipts (which reset also never deletes), so the stale green receipt
keeps reporting `engine ✅ d/t` for tests that no longer exist. The RED
run captured all three surfaces agreeing on a lie.

## Fix shape (assessment remediation a+b+c+d, minimal)

- `services/journal.dart` — `JournalWriter.appendResetTombstone()`:
  appends one `cycle: meta / phase: reset / result: reset` entry whose
  `behaviors` field names every dropped behavior id (the additive
  per-behavior evidence invalidation; `reset` joins the `journalPhases`
  vocabulary so the generated schema and entry validator stay in sync).
  `JournalReader.tombstonedBehaviors(featureDir)`: the LAST reset
  tombstone's ids, empty when none. `_deriveVerdict` gains the
  store-to-tree demotion: a green lane receipt naming a behavior whose
  green evidence has no backing test file demotes to `red` with an
  `evidence-without-artifact` note naming the one recovery.
- `services/cycle_evidence.dart` — `orphanedGreenEvidence(projectRoot:)`:
  the shared primitive — for each behavior, the LAST green entry's
  `- test:` path (absolute or project-relative, the doctor's own
  normalization rules) must exist on disk, else the evidence is orphaned.
  Entries without a `- test:` line are conservatively treated as backed
  (legacy tolerance).
- `commands/reset_command.dart` — after the deletes, append the tombstone;
  the diff summary gains a `will invalidate the green evidence of N
  dropped behavior(s) (journal tombstone)` line BEFORE acting, and the
  verdict details carry `invalidated_behaviors`.
- `commands/run_driver_core.dart` — the reconcile subtracts
  `tombstonedBehaviors` from the red and green evidence sets before
  FR-003 reconciliation, so dropped behaviors re-drive from gen (the
  registry is gone, so `hasGenArtifacts` is false and `_stepsFor` starts
  at 0) instead of skipping as done.
- `commands/doctor_command.dart` — new check 2d between the registry
  missing-files check and the import-drift check: any orphaned green
  evidence adds an `evidence-without-artifact:` drift naming the behavior
  and the missing path, prescribes exactly one recovery
  (`zfa tdd run <feature>` — resume re-drives at gen), exit 1. The doc
  comment's priority list names the new case under `resume`.

Nothing else changed. The brownfield bug-682 bootstrap is untouched
(no tombstone → evidence honored exactly as before; run_command_test
49/49 proves it), and reset's foreign-file rule is untouched.

## Test-first evidence

| Behavior | Class | Evidence |
| --- | --- | --- |
| A1 — reset appends a journal tombstone (meta/reset/reset) naming the dropped behaviors | PROVEN | RED: journal.json absent after reset pre-fix; post-fix the entry exists with `behaviors == ['U-001','U-002']` and prior entries preserved |
| A2 — doctor reports `evidence-without-artifact` (verdict drift, prescription resume, one fix `zfa tdd run <feature>`) on the post-reset tree | PROVEN | RED: `{"verdict":"healthy","prescription":"none","drifts":[]}` pre-fix; post-fix exit 1 with the drift line and the fix line asserted |
| A3 — doctor stays healthy when green evidence is backed by files | PROVEN | Green pre- and post-fix (the completed-feature control; the new check does not fire on backed evidence) |
| A4 — run re-drives the dropped behaviors from gen (no `already done`) | PROVEN | RED: `2 already done — skipping`, empty step log pre-fix; post-fix the full 8-step gen→verify-red→make→refactor×2 sequence asserted |
| A5 — status demotes the stale green receipt (engine=red + note, exit 1) | PROVEN | RED: `engine=green` + `engine ✅ 2/2` pre-fix; post-fix `engine=red` with the `evidence-without-artifact` note and exit 1 asserted |

## Regression matrix (real runs on the fix HEAD, same session)

| Suite | Fix HEAD | Stashed pre-fix baseline | Delta |
| --- | --- | --- | --- |
| bug_1264_reset_done_state_phantom_test (new) | 5/5 | — | new pins |
| run_command_test (driver, incl. bug-682 bootstrap) | 49/49 | — | 0 |
| unified_journal_commands_test | 12/12 | — | 0 |
| commands/run_engine_command_test + commands/run_skin_command_test | 17/17 | — | 0 |
| tdd_command_smoke_test + bug_911_version_skew_contract_test | 11/11 | — | 0 |
| bug_840_recovery_commands_test | +4/−5 | +4/−5 | identical |
| two_cycle_run_commands_test + bug_828_cycle_log_evidence_integrity_test | +28/−4 | +28/−4 | identical |
| bug_874_doctor_cross_feature_adoption + bug_969_json_verdict_envelope + explain_flag | +47/−4 | +47/−4 | identical |

The 13 baseline failures (5 + 4 + 4) were re-run on the stashed pre-fix
tree in the same session and fail identically there: `gen --adopt` shape
and `--feature`-flag usages that pre-date this branch (environment/test
drift on master, zero relation to the changed files). No new failures.

## Exit criteria (issue expected behavior → proof)

1. After reset, run re-drives every behavior whose artifacts were
   dropped — A4.
2. Doctor detects orphaned evidence as a drift and prescribes exactly one
   recovery — A2 (and A3 proves no false drift on healthy trees).
3. Status does not report green for nonexistent tests — A5.
4. Evidence invalidation is append-only — A1 (tombstone entry; cycle-log
   and prior journal entries untouched).

`dart analyze` on the changed files: No issues found. `dart format
--set-exit-if-changed lib/ test/plugins/tdd/bug_1264_reset_done_state_phantom_test.dart`:
exit 0 (three pre-existing unformatted spec-evidence fixtures under
`specs/1142-adaptive-layout-contract/tdd/evidence/` were deliberately left
as master has them — out of scope for this bug's one-PR constraint).
