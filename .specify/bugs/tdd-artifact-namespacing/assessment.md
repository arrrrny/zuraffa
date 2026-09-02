# Bug Assessment: per-feature TDD artifact namespacing — end the test/tdd ownership collision

- **Slug**: tdd-artifact-namespacing
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/827 ([TDD-120] Per-feature TDD artifact namespacing — end the test/tdd ownership collision (#801 system fix))
- **Verdict**: valid, reproduced at the unit level (gen preflight cross-feature conflict)
- **Severity**: high
- **Epic**: #848 (Wave 1 — unblock the loop)

## Report (verbatim or summarized)

Goal: 120 specs in ONE repo, sequentially, 100% TDD. Today running feature #2 after
feature #1 fails at gen with `ownership conflict` because both write
`test/tdd/a1_test.dart`. Test/subject paths are feature-agnostic
(`test/tdd/<behavior>_test.dart`), but artifacts.json/run-state/cycle-log are
per-feature. Two features cannot coexist in the flat layout; feature N+1 can never
start while feature N's artifacts exist. With 120 sequential specs this blocks 119.

## Symptom

`zfa tdd gen <id>` for feature-2 exits non-zero with an FR-008 `OwnershipConflict`
(`... exists on disk but the registry has no recorded ownership`) because
feature-1's registry — not feature-2's — is the one that owns the identically-named
flat artifact.

## Reproduction

1. Seed `specs/feature-1/tdd/test-list.md` and `specs/feature-2/tdd/test-list.md`,
   each with a unit behavior `A1` (same id, different descriptions).
2. `zfa tdd gen A1 --feature feature-1` → exit 0, writes `test/tdd/a1_test.dart`.
3. `zfa tdd gen A1 --feature feature-2` → exit 1, `ownership conflict`:
   `test/tdd/a1_test.dart` exists on disk and feature-2's registry has no record.

## Suspected Code Paths (confirmed)

- `lib/src/plugins/tdd/commands/gen_command.dart:270-275` — the ONLY flat path
  construction site: `'$cwd/test/tdd/${snakeId}_test.dart'` and
  `'$cwd/lib/tdd/${snakeId}_subject.dart'`; `runnableTestName` is derived from the
  flat test path (`<testPath>::<id>::<description>`).
- `lib/src/plugins/tdd/services/artifact_registry.dart` — per-feature registry at
  `specs/<feature>/tdd/artifacts.json`; `preflight` throws `OwnershipConflict` when
  the file exists without a record in THIS feature's registry (correct behavior;
  the paths it guards are wrong).
- `lib/src/plugins/tdd/commands/run_command.dart:1047-1076` —
  `_hasPendingWithArtifacts` checks the flat gen default layout
  `test/tdd/<snake_id>_test.dart` for pending redness on disk (bug #734 v2).
- `lib/src/plugins/tdd/commands/gen_command.dart:411-507` — `_regenerateStaleStub`
  renders the current pair into a temp mirror hardcoded to `<tmp>/test/tdd` +
  `<tmp>/lib/tdd`; with deeper namespaced real paths the mirrored relative
  test→subject import would differ from the real render (byte comparison broken).
- Downstream consumers (`make`, `verify-red`, `wire`, `func`, `compose`,
  `refactor`) all read `record.testPath` / `record.subjectPath` /
  `record.runnableTestName` from the registry — they follow the registry
  automatically once gen records namespaced paths.
- `lib/src/plugins/tdd/services/composition_targets.dart` — compose anchors
  resolve per-feature via registry records + green cycle-log evidence; there is no
  filename-based cross-feature resolution today, and this fix adds none (cross-
  feature subject resolution stays behind explicit dependency edges — zero edges
  today, zero cross-feature resolution after this fix).

## Root Cause

The artifact path convention (`test/tdd/<snake-id>_test.dart`,
`lib/tdd/<snake-id>_subject.dart`) has no feature dimension, while every registry
that grants ownership of those paths is per-feature. Two features that both plan a
behavior with the same id (the normal case: A1 everywhere) map to the same artifact
file, so the second feature's gen is refused by a guardrail that is working as
designed.

## Remediation (minimal, per the issue's system-fix list)

1. Namespace all generated artifacts by feature-slug in `gen_command.dart`:
   `test/tdd/<feature-slug>/<snake-id>_test.dart`,
   `lib/tdd/<feature-slug>/<snake-id>_subject.dart`. The feature-slug is the spec
   directory basename (`044-test-tdd-generation`), which gen already resolves and
   records.
2. `runnable_test_name` and the registry records inherit the namespaced paths
   (single construction site).
3. Migration for existing projects: `zfa tdd migrate-paths` moves recorded
   artifacts from the flat layout to the namespaced layout and rewrites the
   registry records (paths + runnable name). Idempotent, `--dry-run` supported,
   refuses a move when the target already exists (ownership guardrail preserved),
   leaves unrecorded flat files alone, and never touches a progressed subject.
4. `_hasPendingWithArtifacts` (run driver) checks the namespaced path first and
   keeps the legacy flat path as a fallback, so un-migrated (flat) projects keep
   their #734 deferral semantics.
5. `_regenerateStaleStub` mirrors the real relative test→subject structure instead
   of hardcoded `<tmp>/test/tdd` + `<tmp>/lib/tdd`, so the #683 byte comparison
   stays exact for namespaced (and legacy) layouts.

### Alternatives rejected (from the issue/assessment, with reasons)

- Teach gen to overwrite foreign files — explicitly rejected in the issue; it
  breaks the 044 ownership contract (FR-008) and risks clobbering a progressed
  subject.
- Do nothing / run features in separate checkouts — rejected: the 120-spec corpus
  runs in ONE repo by definition (issue context).
- Auto-upgrade (silent migration on first run) instead of an explicit command —
  the issue allows either; the explicit `zfa tdd migrate-paths` was chosen because
  it never moves files the user did not ask to move, keeps `gen` side-effect-free
  with respect to unrelated artifacts, and matches the house fail-honest pattern
  (report what was skipped and why). A flat project that never runs the command
  keeps working: suite discovery is under `test/`, run's legacy path check stays,
  and registry-driven commands keep reading the recorded (flat) paths.

## Constraints honored

- Migration must not break existing flat-layout projects (legacy paths still
  honored by run's disk check; registry-driven commands follow records; migrate is
  opt-in and idempotent).
- `flutter test` / `dart test` must still discover all tests (everything stays
  under `test/`).
- Ownership guardrail keeps working against namespaced paths (same preflight, new
  paths; verified by tests).
- Cross-feature subject resolution uses explicit dependency edges only — none
  added, none removed; compose keeps per-feature anchor discovery via the
  registry.
- No gate eased; one PR for this bug only.

## Risks & Considerations

- Mixed state (a feature with flat records for old behaviors and namespaced
  records for new ones) is safe per-behavior: preflight compares paths only within
  the same behavior id's record. The mismatch conflict a re-gen of an OLD flat
  behavior produces names the migration command as the way out.
- `examples/todo_tdd/` ships pre-existing flat-layout artifacts and pre-existing
  analyzer errors; it is regenerated content outside this fix's scope.

## Open Questions

- None blocking; the explicit-command migration variant was selected over
  auto-upgrade as noted above.
