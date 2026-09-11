**Template Version**: `zuraffa-1.0`

# Plan: 1518-gen-guard-warning-pre-1483-remedy

## Technical Context

- **Language/toolchain**: pure Dart CLI (Dart SDK ^3.11.0); no Flutter SDK
  dependency on this package's own test path.
- **Feature surface** (all messaging/warning layer — issue #1518 hard
  constraint: detection, stop, and loop semantics are untouched):
  - `lib/src/plugins/tdd/services/behavior_test_writer.dart` — the gen-time
    guard-only warning (issue #1308) prints
    `--> fix: $vacuousGuardFallbackRemedy` (line ~198): the pre-#1483
    constant with the lane plan hardcoded as a bare `04-ENGINE.md`. For a
    legacy single-file feature that file does not exist. ADDS: the seam
    context (`projectRoot`, `featureDir`) on the constructor (nullable —
    `const BehaviorTestWriter()` keeps compiling), the private
    `_guardOnlyRemedy` resolving the seam from disk through the shared
    `lanePlanSeamPath` resolver (`LaneSplitFiles.engine` →
    `LaneSplitFiles.skin` → test list, relativized against the project
    root) and the `vacuousGuardFallbackRemedyFor` wording, and
    the conservative feature-derived test-list branch for the no-context
    direct-library case.
  - `lib/src/plugins/tdd/commands/run_driver_core.dart` —
    `_forwardGuardOnlyWarning` (line ~2358) scans the gen child's captured
    output for lines containing `vacuousGuardWarningToken` OR
    `vacuousGuardFallbackRemedy`. The second key dies with the constant
    (the branched remedy text is dynamic). ADDS: the token-anchored scan —
    forward the token line AND the `--> fix:` remedy line directly after it
    — via the shared pure scanner `guardOnlyWarningLinesToForward` (below).
    `_vacuousFallbackRemedy` now delegates its seam probe to the same
    shared `lanePlanSeamPath` resolver (D6); its printed output is
    byte-unchanged.
  - `lib/src/plugins/tdd/services/vacuous_guard.dart` —
    `vacuousGuardFallbackRemedyFor` (issue #1483) is the branched wording
    builder — now the ONE remedy source. RETIRES:
    `vacuousGuardFallbackRemedy` (the pre-#1483 bare-`04-ENGINE.md`
    constant, its doc history folded into the branched builder's doc).
    ADDS: `lanePlanSeamPath({projectRoot, featureDir})` — the ONE
    seam-resolution rule (engine plan → skin plan → null) shared by the
    writer and the run driver, so the rule that picks the seam path cannot
    drift (D6); and `guardOnlyWarningLinesToForward(String output)` — the
    pure forwarding scanner (the token line, then the `--> fix:` line on
    the line DIRECTLY after it; nothing else), so the writer→forwarder
    wording contract is testable as a round trip without spawning the
    driver.
  - `lib/src/plugins/tdd/commands/gen_command.dart` — `_writersFor`
    constructs `BehaviorTestWriter(...)` for the real write (~line 1505)
    and the staleness mirror renders through the same dispatch. ADDS:
    optional `projectRoot`/`featureDir` threading through `_writersFor`
    and `_regenerateStaleStub` so BOTH prints (real write + staleness
    mirror) carry the same branched wording — the mirror already prints
    the warning today, so leaving it contextless would reintroduce a
    contradictory pair inside one gen output.
  - `test/plugins/tdd/commands/bug_1320_declared_assertion_reachable_test.dart`
    — U8 pins the remedy wording (the byte-pin constraint named by the
    issue). MIGRATES: the pin from the retired constant to the branched
    builder (both branches carry the wording family).
  - `test/plugins/tdd/bug_1483_vacuous_green_remedy_shape_test.dart` —
    U-1483-1c pins the constant BYTE-EXACTLY ("the pre-#1483 shared
    constant is unchanged"). MIGRATES: the byte-pin to the two branched
    outputs (byte-exact, path-separator agnostic via `p.join`).
  - `test/plugins/tdd/issue_1308_vacuous_guard_remedy_test.dart` —
    U-1308-1 byte-pins the constant; U-1308-2 asserts the writer's printed
    remedy contains the constant. MIGRATES both to the branched builder /
    the branched printed wording.
- **New suites** (the red-green loop drives these):
  - `test/plugins/tdd/bug_1518_gen_guard_warning_seam_test.dart` (fast) —
    the writer's branched warning over every shape + the scanner round
    trip + the surgical-scan guard.
  - `test/plugins/tdd/bug_1518_gen_guard_warning_forward_driver_test.dart`
    (slow, `@Tags(['slow'])`) — the REAL run pipeline over the scripted
    fake zfa (the issue #1308/#1483 driver-suite convention): the fake gen
    prints the branched warning, the fake make refuses vacuous-green, and
    the transcript must carry TWO AGREEING `--> fix:` lines (the issue's
    exact bug scenario, inverted into the acceptance proof).
  - `test/plugins/tdd/commands/bug_1518_gen_command_seam_test.dart` (fast) —
    the REAL `GenCommand` (review fix): G-1518-1 (legacy single-file) and
    G-1518-2 (lane-split + a reused second run reaching the staleness
    mirror) pin the gen-threaded seam context end to end (FR-004/T4).

## Key decisions

- **D1 — the writer resolves the seam from DISK, with context provided by
  gen.** The feature dir is genuinely ambient state (it may be
  `specs/<name>` or a `.specify/bugs/<slug>` dir per issue #1471 — the
  writer cannot guess it from `behavior.feature`). gen KNOWS the resolved
  `featureDir` and passes it (plus the project root) through the writer
  constructor; the write() signature is untouched, so every existing
  direct-library caller keeps compiling. Without context the writer
  prints the conservative legacy single-file branch (the canonical
  `specs/<feature>/tdd/test-list.md`) — strictly better than the retired
  wording, which named a file that NEVER exists for that shape.
- **D2 — the forwarding scan keys on the TOKEN, not the remedy text.** The
  branched remedy is dynamic (paths differ per feature), so a
  text-contains scan on the remedy cannot survive #1518. The writer's
  warning shape is stable — the token line, then the `--> fix:` line — so
  the scan forwards a token line and (only) the remedy line that
  immediately follows. The scanner lives in `vacuous_guard.dart` next to
  the token so the wording contract is one import away and fast-tier
  testable as a writer→forwarder round trip (U-1518-5).
- **D3 — the constant is retired, not deprecated.** The bug exists because
  two wordings coexisted (the hardcoded constant + the branched builder);
  keeping the hardcoded one alive invites the next caller to regress.
  Every pin migrates in the same change (the issue's stated protocol), so
  the retirement is atomic: no consumer, no pin, no dead wording.
- **D4 — the staleness mirror gets the same context as the real write.**
  The mirror render (issue #1320's verdict machinery) calls the same
  `write()` and already prints the warning today; contextless it would
  print the no-context branch while the real write prints the
  disk-resolved branch — a NEW contradictory pair inside one gen output.
  Threading the context through `_regenerateStaleStub` keeps one wording
  per transcript.
- **D5 — the run side's OBSERVABLE behavior is untouched.** `_vacuousFallbackRemedy`
  (the #1502 code) already branches correctly and is pinned by the #1483 driver
  suites; the forwarding call site and the stop arm are unchanged. Only the scan
  body changes, and U-1308-4 (the fake's old-shape token+fix lines) still
  forwards — the scan is shape-compatible with both the old fake output
  and the new writer output.
- **D6 — ONE seam-resolution rule, shared (review fix).** #1518 exists
  because two copies of one thing (the wording) drifted; leaving the
  engine→skin→test-list path PROBE duplicated between the writer and the
  run driver would preserve the same drift mechanism for the next seam
  change (a new lane-plan filename, a `04-CONTRACT.md` preference, a
  `.specify/bugs/<slug>` layout). `lanePlanSeamPath` in `vacuous_guard.dart`
  is the single resolver; `_guardOnlyRemedy` and `_vacuousFallbackRemedy`
  both call it. The scanner's adjacency contract is likewise enforced, not
  just documented: the fix line is accepted only on the line directly after
  the token line (`--> fix:` is a shared convention across the codebase).

## Risks / notes

- The #1308 fast suite's U-1308-2 asserts the printed remedy contains the
  retired constant; the migration rewrites that assertion to the branched
  no-context wording (`specs/1308-vacuous-guard-remedy/tdd/test-list.md`
  — derived from the behavior's feature name, the documented D1
  fallback). The test's tmp dir carries no lane plan, so the branch is
  the test list by construction.
- `dart test` defaults to the fast tier (`exclude_tags: slow`); the new
  driver-level suite carries `@Tags(['slow'])` like the #1308/#1483
  driver suites and is run explicitly.
- The forwarder's "immediately follows" contract: the writer prints the
  fix line directly after the token line (two `print` calls, no
  interleaving in a single-threaded zone), and the fake binaries in the
  #1308/#1483 suites echo the same two-line shape — the scan holds for
  both.
