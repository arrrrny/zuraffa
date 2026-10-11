# Tasks: 1482-tdd-run-preflight

MVP first: the preflight service + its unit suite (the refusal contract),
then the command wiring (`--force`, refusal block, journal, exit), then the
regression sweep. Every behavior task is TDD-driven (red → green) per
`tdd/test-list.md`.

## Phase 1 — MVP: the preflight gate (behaviors U-1482-1 … U-1482-5)

- [x] T001 (U-1482-1) Implement `RoutingProvenancePreflight.check()`:
      read rows via `TestListReader`, parse the `## Routing provenance`
      `route:` lines (test-list.md, following `LaneSplitFiles` into
      04-ENGINE.md / 04-SKIN.md), classify unit rows. Test: service test
      seeds a test list whose U1 is fallback-routed and asserts the
      finding (id, description, FR token) and `ok == false`. RED first.
- [x] T002 (U-1482-2) The offending-row filter: unit kind + fallback
      provenance + state != done + (no generated test OR
      `contentIsVacuousGreen`). Test: acceptance fallback rows, declared
      unit rows, DONE fallback rows, and fallback rows with a
      hand-completed (non-vacuous) test are NOT offending. RED first.
- [x] T003 (U-1482-3) Fail-open boundaries: no test list (or unreadable)
      → vacuous pass; missing provenance section → vacuous pass; lane
      meta-index lists resolve provenance from the lane plans. RED first.
- [x] T004 (U-1482-4) Wire the preflight into `RunCommand._run` after the
      #1303 gate: on findings, print the exact refusal block (header, one
      line per row with the `, fallback to FR-00N` suffix rule, Suggested
      line), journal `preflight_red`, print the all-zero `result=stopped`
      summary line, exit 1, zero steps spawned. Test: `CliRunner`
      transcript + exit code + journal + argv log is EMPTY. RED first.
- [x] T005 (U-1482-5) Add `--force`: bypasses only the routing preflight;
      the loop then drives exactly as before (the honest vacuous-green
      stop preserved). Test: driver run over a scripted fake zfa with
      `--force` reaches the loop; the #1303 gate still fires with `--force`
      when its own condition holds. RED first.

## Phase 2 — Non-behavioural

- [x] T006 Regeneration hygiene: `dart format` on changed files; no
      analyzer issues on the changed set (verify phase).
- [x] T007 Docs: the command's library doc names the new preflight and
      the #1482 issue; `--force` help text names the issue.

## Phase 3 — Regression sweep (verify phase)

- [x] T008 Re-run the scoped suites: `run_command_test.dart`,
      `run_engine_command_test.dart`, `run_skin_command_test.dart`,
      `bug_1259_vacuous_green_test.dart`, the new 1482 suites — all green;
      record evidence in `tdd/verification.md`.
