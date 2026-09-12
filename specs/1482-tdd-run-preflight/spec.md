**Template Version**: `zuraffa-1.0`

# Spec: 1482-tdd-run-preflight

## Summary

`zfa tdd run <feature>` has no routing preflight. It certified 19 reds over
27m41s on `001-todo-app` before stopping at `U1:make` — a failure whose
precondition (all 21 unit behaviors fallback-routed with no derivable
assertion) was already fully known at plan time, for every behavior, before
the run started. The engine cycle is expensive by design (a `flutter test`
spawn per `verify-red`), so the first fatal condition must be detected
BEFORE the loop starts. This feature adds a preflight to `zfa tdd run`:
before the first `gen`, the run reads the feature's routing provenance (the
`## Routing provenance` section `zfa tdd plan` already writes) and refuses
to start when any unit behavior is fallback-routed with no derivable
assertion, naming ALL offending rows at once. `--force` bypasses the
preflight; the existing honest stop remains the fallback for conditions
unknown at plan time. `zfa tdd plan`, `zfa tdd verify`, and the loop
semantics are untouched.

## Acceptance Scenarios

1. **Given** a feature whose test list marks at least one UNIT behavior
   fallback-routed (`route: <id> -> unit lane [fallback: ...]` in the
   plan-produced `## Routing provenance` section) with no derivable
   assertion (no generated test, or a vacuous one) **When** `zfa tdd run`
   starts **Then** it refuses BEFORE the first `gen`/`verify-red` step
   spawns, printing once:
   `run: preflight failed — N unit behaviour(s) cannot pass make:` followed
   by one line per offending row
   (`  <id> — <description> (no declared contract trace, fallback to
   FR-00N)`) and the remedy line
   `Suggested: fix routing in plan, or run \`zfa tdd run --force\` to skip
   preflight.` — and the final summary line keeps the machine contract
   (`run: feature=<f> result=stopped pending=0 red=0 green=0 done=0`) with
   a non-zero exit code and zero steps spawned.
2. **Given** several unit behaviors are fallback-routed **When** the
   preflight evaluates the routing provenance **Then** ALL offending rows
   are listed at once (id, description, the FR the row falls back to) —
   the author fixes the plan in one pass instead of one stop per row.
3. **Given** `--force` **When** the run starts **Then** the routing
   preflight is bypassed entirely and the loop drives as before — the
   existing vacuous-green honest stop (`stopped_at=<id>:make`, the #1259 /
   #1308 remediation) remains the fallback for conditions unknown at plan
   time.
4. **Given** a feature whose unit behaviors are all declared-routed
   (contract-row traces) or whose fallback-routed units already carry real
   assertions (hand-completed tests, loop-complete DONE rows) **When**
   `zfa tdd run` starts **Then** the preflight passes vacuously and the
   run proceeds unchanged — the gate invents no refusal the routing data
   does not prove.
5. **Given** any feature (not only `001-todo-app`) **When** the preflight
   runs **Then** it consults ONLY the plan-produced artifacts (the test
   list rows + the routing provenance section, following the lane
   meta-index into `04-ENGINE.md` / `04-SKIN.md` when present) — no
   re-planning, no spec re-parse, no step spawn: O(1) reads.
6. **Given** a feature with no test list (unplanned) **When** the run
   starts **Then** the preflight fails open (the driver's own missing-list
   error names the real problem downstream) — the preflight's SINGLE
   contract is the fallback-routed-unit refusal, everything else fails
   honestly downstream.

## Functional Requirements

- **FR-001**: Before the first gen step, `zfa tdd run` MUST read the
  feature's routing provenance (the plan-produced `## Routing provenance`
  section) and identify every UNIT behavior that is fallback-routed with
  no derivable assertion. A row is offending when: its kind is `unit`;
  its provenance line is `[fallback: ...]`; its loop state is not `done`;
  and it has no generated test carrying a real (non-vacuous) assertion set
  (`contentIsVacuousGreen`, issue #1259, is the sole assertion predicate).
- **FR-002**: When any offending row exists, the run MUST refuse to start
  and emit the structured error listing ALL offending rows at once in the
  exact shape: `run: preflight failed — N unit behaviour(s) cannot pass
  make:` / `  <id> — <name> (no declared contract trace, fallback to
  FR<id>)` / `Suggested: fix routing in plan, or run \`zfa tdd run
  --force\` to skip preflight.` A row with no FR-shaped trace token omits
  the `, fallback to FR<id>` suffix.
- **FR-003**: `--force` MUST bypass the routing preflight (and only the
  routing preflight — the #1303 dependency-overrides gate and the #1001
  cert gate keep their own semantics). The existing honest stop stays the
  fallback for runtime conditions unknown at plan time.
- **FR-004**: The refusal MUST exit non-zero (the run's `stopped` class,
  exit 1), journal the refusal as `preflight_red` at the `gate` phase with
  one violation per offending row, print the final summary line
  (`result=stopped`, all-zero counts — the #1303 preflight precedent), and
  spawn zero steps.
- **FR-005**: The preflight MUST be O(1): it reads the cached routing
  data (test list + provenance section, following the lane meta-index
  when present) and at most one generated test file per candidate row. It
  MUST NOT re-plan, re-parse the spec, or spawn any subprocess.
- **FR-006**: The preflight MUST consult the routing provenance that plan
  already produces — it MUST NOT duplicate the routing ladder
  (`RoutingResolver` stays the single owner) and MUST NOT change `tdd
  plan`, `tdd verify`, or any loop step semantics.

## Measurable Success Criteria

- **SC-1**: On a feature with N fallback-routed unit rows (N ≥ 1, no
  generated tests), `zfa tdd run` exits non-zero in under one second of
  wall clock with zero `gen`/`verify-red`/`make` spawns, and the transcript
  names all N rows in one block (the #1482 repro: 21 rows named, not one
  stop 27m41s in).
- **SC-2**: The same command with `--force` proceeds into the engine lane
  (the honest stop at the first vacuous-green make is preserved and
  byte-identical to today's).
- **SC-3**: `dart analyze` clean on every changed file; the new unit +
  driver suites pass; the existing `run_command_test.dart`,
  `run_engine_command_test.dart`, `run_skin_command_test.dart`, and
  `bug_1259_vacuous_green_test.dart` suites pass unchanged (no loop
  semantics drift).
- **SC-4**: Works for any feature directory layout the run driver already
  resolves (the #1471 pin included — bug features under
  `.specify/bugs/<slug>/`).

## Related

- #1482 (this feature), #1308 (CLOSED — the vacuous-green remedy the
  honest stop keeps prescribing), #1374 (CLOSED — run economics, different
  mechanism), #1259 (CLOSED — the vacuous-green refusal the assertion
  predicate reuses), #951 (CLOSED — the routing provenance artifact the
  preflight reads).
