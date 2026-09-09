# Spec 1331 — fix: reset deletes all owned files (validates its outcome); make adopts re-driven subjects; doctor prescription matches reality

GitHub issue: arrrrny/zuraffa#1331 (severity high — the documented recovery
loop reset → run does not produce a clean re-drive; companion to #840 reset
semantics)

## Problem

After a feature is driven to `result=complete` (all behaviors green),
`zfa tdd reset <feature>` + `zfa tdd run <feature>` — the documented
recovery loop — does not produce a clean re-drive. Reset dropped all 6
registry records but deleted only the SKIN behavior's files (A1's
test+subject); the ENGINE files (a2, a3, u1-u3) remained on disk with
their green implementations. The subsequent run dead-ends, and
`zfa tdd doctor`'s prescription for exactly this drift does not hold.

Repro:

```
# feature driven to result=complete (all behaviors green)
zfa tdd reset <feature>        # "dropped=6", deletes only some owned files
zfa tdd run <feature>
# -> A2 verify-red -> unexpected-green / skipped (already green)
#    A2 make -> subject-drift => result=stopped
zfa tdd doctor <feature>
# drift: evidence-without-artifact
# --> fix: zfa tdd run <feature> (run reconciles to pending, re-enters at gen)
zfa tdd run <feature>          # dead-ends again at A2:make subject-drift
```

Root cause (traced):

- `reset_command.dart` builds `ownedExisting` from the registry records'
  raw `testPath`/`subjectPath` values with `File(path).existsSync()` —
  the raw path is resolved against the PROCESS CWD when relative, and an
  absolute path recorded by another checkout/worktree/gen-time layout can
  never match the current tree. Records whose paths no longer matched
  on-disk paths at reset time (path drift) had their files classified
  foreign and kept while the records were still dropped — the half-state.
  Reset also prints "will delete N owned files" with no post-deletion
  validation that the printed list matches what was actually deleted, and
  emits no warning when a record's paths did not exist.
- Acceptance-lane subjects are green-by-construction after compose; a
  fresh gen writes a new stub whose capture-guard test is instantly
  green, so red→green cannot re-certify. Make's issue #1036
  subject-drift guard then compares the current subject hash against the
  SURVIVING pre-reset green evidence hash (the cycle-log is append-only
  and reset never touches it; the #1264 tombstone invalidates evidence
  for the run driver's reconciliation but make never consults it) and
  refuses: `subject-drift` => `result=stopped`. The documented recovery
  loop can never re-drive a reset feature.

## Deliverables

1. **Reset validates its own outcome.** After dropping records, reset
   MUST report every generated-shape file it classified
   foreign-but-owned-looking BY NAME (a file whose provenance header
   names a dropped behavior id but which another feature's live registry
   owns), and MUST warn when a dropped record's recorded paths did not
   exist on disk at reset time (path drift) instead of silently keeping
   the files. The printed "will delete N owned files" list MUST match
   the actual deletions (validated after acting, survivors reported).

2. **Reset deletes ALL owned files.** Reset MUST delete every file
   associated with every dropped registry record — not only the ones
   whose recorded paths still match at reset time. Recorded paths are
   normalized against the project root (absolute and project-relative
   forms resolve identically — the #912/#1312 class), and the generated
   layouts (`test/tdd`, `lib/tdd`, recursively — the namespaced layout
   lives in feature subdirectories) are scanned for generated-shape
   files whose provenance names a dropped behavior id, so a path-drifted
   file is still deleted. Cross-registry safety stands: a file another
   feature's live registry owns is foreign-owned and is NEVER deleted
   (reported by name instead). Files that no registry record and no
   provenance header ties to a dropped behavior stay foreign (kept,
   counted, never touched — the #840 hard constraint).

3. **Make handles re-drive of existing implemented subjects.** When the
   on-disk subject for a behavior is complete-but-unowned (the registry
   was just reset — the behavior is tombstoned by the last reset and its
   surviving green evidence predates that tombstone), make MUST adopt
   the passing subject and skip straight to green certification with an
   EXPLICIT `adopted` outcome (exit 0, green evidence entry appended
   binding the current subject hash) instead of refusing with
   `subject-drift`. The #1036/#1162 refusal semantics are PRESERVED for
   every non-re-drive class: a green-basis drift whose last green
   evidence postdates the last reset, a red-basis drift on a born-green
   placeholder, and the vacuous-green gate all keep refusing exactly as
   before. The run driver and the step runner accept `adopted` as a
   terminal make success (the loop advances: green, then refactor).

4. **Doctor's prescription matches reality.** `zfa tdd doctor`'s
   prescription for the `evidence-without-artifact` drift class MUST
   describe what `zfa tdd run` actually does after deliverable 3: run
   reconciles the tombstoned behaviors to pending, re-enters at gen, and
   make adopts each re-driven subject whose certification the reset
   invalidated (the `adopted` outcome) — the loop completes instead of
   dead-ending at `subject-drift`.

## Success Criteria (measurable)

- **SC-1 (reset deletes all owned files):** Given a completed feature
  whose registry records carry paths that no longer match the on-disk
  artifact locations (relative form resolved against a different CWD, or
  a file living at a drifted path in the generated layouts), `zfa tdd
  reset` deletes the recorded-path files AND every generated-shape file
  whose provenance names a dropped behavior id. After reset, `test/tdd`
  and `lib/tdd` (recursively) contain no file naming a dropped behavior
  id. Measured by the spec's TDD behaviors B1/B2.
- **SC-2 (reset validation + drift warnings):** Reset's stdout names
  every path-drift warning (`record's path did not exist` class) and
  every foreign-but-owned-looking file by name; the verdict JSON carries
  the same details (`path_drift`, `foreign_owned_looking`,
  `deleted_files`); the reported deleted-file count equals the number of
  files actually deleted (post-deletion re-stat proves zero survivors).
  Measured by behaviors B3/B4.
- **SC-3 (foreign files never deleted):** A generated-shape file that
  ANOTHER feature's live registry owns survives reset and is reported by
  name; files with no provenance tie to a dropped behavior survive
  untouched. Measured by behavior B5.
- **SC-4 (make adopts the re-drive class):** Given a tombstoned behavior
  whose surviving green evidence predates the last reset and whose
  target test passes against the on-disk subject, `zfa tdd make` exits 0
  with `outcome=adopted`, appends a green evidence entry carrying the
  CURRENT subject hash, and the run loop advances (make → refactor →
  done). Measured by behaviors B6/B7.
- **SC-5 (refusal classes preserved):** A green-basis subject drift
  whose last green evidence POSTDATES the last reset (or a feature with
  no reset tombstone at all) still refuses with `subject-drift`; the
  born-green placeholder red-basis refusal and the #1259 vacuous-green
  gate are untouched. Measured by behavior B8.
- **SC-6 (run completes the re-drive; doctor truthful):** After
  `reset` on a completed feature, `zfa tdd run <feature>` reaches
  `result=complete` (no `subject-drift` stop), and `zfa tdd doctor`'s
  `--> fix:` line for `evidence-without-artifact` names the re-drive
  adoption the run actually performs. Measured by behaviors B9/B10.
- **SC-7 (no regressions):** The existing reset/make/doctor/run suites
  for the touched contracts pass unchanged (only the files this spec
  names are modified).

## Scope Fence (hard constraints)

- Fix ONLY `reset_command.dart` (owned-file deletion + validation), the
  make/verify-red re-drive handling (the `adopted` outcome + its step
  runner/run driver acceptance), and doctor's prescription text.
- Do NOT change the core engine cycle, the gen/make/compose/view
  pipeline, the refactor pass, or the verify gate semantics.
- Do NOT weaken the #840 foreign-file guarantee: files no dropped record
  and no provenance header tie to this feature are never deleted.
- Do NOT weaken #1036/#1162 refusal semantics outside the tombstoned
  re-drive class, and do NOT touch the #1259 vacuous-green gate.
- One PR per issue (arrrrny/zuraffa#1331).

## Risks and Mitigations

- **Risk:** recursive provenance scan deletes a hand-written file that
  happens to carry a dropped behavior id in a comment.
  **Mitigation:** the scan requires the generated shape
  (`matchesGeneratedTestShape` / `matchesGeneratedSubjectShape` — the
  provenance header AND the behavior id marker), the same two-signal
  test gen's adopt path uses; unmarked files are never candidates.
- **Risk:** adopting a placeholder subject certifies green on a subject
  the red evidence never exercised (the #1036 born-green class).
  **Mitigation:** adoption is gated on the tombstone (the user's
  explicit "start over") AND the last green evidence predating it; the
  outcome is explicitly `adopted` (distinguishable in accounting, never
  conflated with `skipped` or `green`), and the appended evidence binds
  the current subject hash so any later drift still refuses.
- **Risk:** timestamp comparison misparses legacy entries.
  **Mitigation:** an unparseable/absent tombstone or evidence timestamp
  fails CLOSED (no adoption — the refusal stands), matching the house
  safe-failure rule.
