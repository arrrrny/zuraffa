# Bug Assessment: `zfa tdd make` returns unexpressible for non-entity behaviors — no generator surface for plain functions

- **Slug**: unexpressible-non-entity
- **Created**: 2026-08-31
- **Source**: https://github.com/arrrrny/zuraffa/issues/657 (fetched verbatim into `issue.md`)
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

GitHub issue #657 (see `issue.md` for the verbatim body): `zfa tdd make` returns
`unexpressible` for behaviors that don't map to a zuraffa generator surface, and
`zfa tdd run` stops at the first such behavior, blocking the whole feature. Two
real cases: forklift spec 004 U1 ("`render` returns a non-empty string for a
fully populated task") and spec 003 U3 ("System MUST provide a conversational
interface between the operator"). Both hit `zfa tdd make: cannot plan a
generation for behavior ... no generator surface maps the behavior description
to a \`zfa entity create\` / \`zfa make\` / \`zfa build\` invocation.`

## Symptom

`zfa tdd make <behavior-id>` exits non-zero with outcome `unexpressible` for any
behavior whose description describes a plain function (render / format / parse /
compute / pure logic) rather than an entity, CRUD/use-case, repository, or
service. In `zfa tdd run <feature>`, the first such unit behavior stops the
entire run (`step failed — behavior=U1 step=make outcome=unexpressible`) before
later behaviors execute.

## Reproduction

1. Create a feature whose test list contains a unit behavior described like
   "`render` returns a non-empty string for a fully populated task".
2. `zfa tdd init --feature <feature>`; `zfa tdd gen <id>`; `zfa tdd verify-red <id>` (certifies red).
3. `zfa tdd make <id>` — the planner returns an unexpressible plan and the
   command exits 1 with outcome `unexpressible`.
4. `zfa tdd run <feature>` — the run hard-stops at that behavior's `make` step;
   later behaviors never execute. [Confirmed by code reading; not re-run
   end-to-end against the forklift repo — the planner and driver code paths
   below pin the behavior deterministically.]

## Suspected Code Paths

- `lib/src/plugins/tdd/services/generation_planner.dart:83-174` —
  `GenerationPlanner.plan()` is the SOLE behavior→pipeline translation layer.
  It recognizes exactly two mappings: (1) entity-bearing descriptions
  ("create entity X" / "entity ... with") → `entity create` + `tdd wire` +
  `build`; (2) CRUD/use-case/repository/service descriptions → `make <slug>` +
  `build`. Everything else falls to `_unexpressibleReason()` (line 204) —
  plain-function verb phrases (render, format, parse, compute, return) have no
  branch.
- `lib/src/plugins/tdd/commands/make_command.dart:276-289` — when
  `plan.isExpressible` is false the command prints the unexpressible reason and
  exits 1 with `MakeOutcome.unexpressible`. The message names the gap but gives
  no actionable remediation (no verb, no stub path, no re-run hint).
- `lib/src/plugins/tdd/commands/run_command.dart:620-661` — the driver's phase-1
  deferral (`deferralAllowed && step == 'make' && row.kind ==
  BehaviorKind.acceptance && result.outcome == 'unexpressible'`, line 627-630)
  defers ONLY acceptance behaviors. A UNIT behavior with outcome
  `unexpressible` falls through to the honest-stop branch (line 640-660): the
  run stops, later behaviors never start — the reported hard stop.
- `lib/src/plugins/tdd/commands/wire_command.dart` — the architectural precedent
  for a new tdd-plugin generation surface: `zfa tdd wire` implements the subject
  stub by rewriting `lib/tdd/<id>_subject.dart`'s `UnimplementedError` body
  (added by bug #610). A plain-function generator belongs in the same plugin
  (core↔plugin dependency direction forbids a core command).
- `lib/src/plugins/tdd/tdd_plugin.dart` / `lib/src/commands/tdd_command.dart:18-30`
  — subcommand registration surface for the new command.
- `lib/src/plugins/tdd/services/pipeline_runner.dart:69-134` — executes plan
  steps as `zfa <args>` subprocesses; a new plan step shape needs no runner
  changes (any args are passed through verbatim).

## Root Cause Hypothesis

Confidence: high. The planner's mapping table is closed over
entity/CRUD/use-case surfaces (spec 047 FR-005 scoped it that way), so
plain-function behaviors are correctly classified `unexpressible` — but two
downstream consumers treat that classification as terminal: `make` exits
non-zero with no remediation path in its message, and the driver defers
`unexpressible` makes only for ACCEPTANCE-kind behaviors (bug #625), so a unit
plain-function behavior deadlocks the whole feature. The gap is a missing
generator surface plus a missing non-stop fallback, exactly as the issue
proposes.

## Proposed Remediation

**Preferred** (matches the issue's three-point direction):

1. **New generator surface — `zfa tdd func <behavior-id>`** (new
   `FuncCommand` in the tdd plugin, registered in `TddCommand`). It resolves
   the behavior record (same resolution rules as `wire`), derives a function
   signature from the behavior description (verb + return type: "returns a
   string" → `String`, "returns a bool/true/false" → `bool`,
   "returns an int" → `int`, "returns a list" → `List<String>`, default
   `String`), and rewrites the gen'd subject stub's `UnimplementedError` body
   with the minimal implementation satisfying the described contract (e.g.
   render → return a non-empty string). Idempotent: an already-implemented
   subject reports `already-implemented` and exits 0. Never touches the paired
   test file (044 ownership contract).
2. **Planner mapping** — add a function-intent branch to `GenerationPlanner`
   BEFORE the misfire fallthrough: descriptions whose leading/containing verb
   phrase is one of `render`, `format`, `parse`, `compute`, `convert`,
   `return` map to steps `['tdd', 'func', <behaviorId>]` + `['build']`
   (every expressible plan still terminates in `build`, U5).
3. **Non-stop fallback** — (a) `MakeCommand`'s unexpressible message gains the
   actionable form from the issue: `no generator for '<verb>'; implement
   manually at <stub_path>, then re-run` (verb = leading verb of the
   description, stub path = the record's `subject_path`). (b) `RunCommand`
   generalizes the bug-#625 deferral: in phase 1, ANY behavior's `make`
   reporting `unexpressible` defers to phase 2 (stays at its last completed
   state) instead of stopping the run, and the phase-2 make re-attempt covers
   every deferred behavior (not only acceptance-kind). The refactor deferral
   condition (`_hasRedAcceptance`) generalizes to "any behavior sits RED" —
   refactor's absolute-green preflight is equally impossible while a deferred
   unit behavior sits red. `unexpressible` at the phase-2 re-attempt remains a
   real, honest stop (FR-007) — by then every other behavior has run, and the
   make-level message tells the operator exactly what to implement manually.

**Alternatives**:

- `zfa func` as a CORE command (the issue's literal `zfa func`): rejected —
  the subject contract (`lib/tdd/<id>_subject.dart`, registry artifacts) is
  owned by the tdd plugin; a core command would need a core→plugin dependency
  the architecture forbids (same reasoning recorded in `wire_command.dart`'s
  design-decision comment).
- Treat unit `unexpressible` makes as skip-and-continue with no phase-2
  re-attempt: rejected — it silently leaves behaviors RED without a terminal
  report, violating the driver's honesty rules (FR-007: bounded partial
  progress must be named, not silently faked).

**Files likely to change**:

- `lib/src/plugins/tdd/commands/func_command.dart` (new)
- `lib/src/plugins/tdd/services/generation_planner.dart`
- `lib/src/plugins/tdd/commands/make_command.dart`
- `lib/src/plugins/tdd/commands/run_command.dart`
- `lib/src/commands/tdd_command.dart`
- `test/plugins/tdd/services/generation_planner_test.dart`
- `test/plugins/tdd/commands/func_command_test.dart` (new)
- `test/plugins/tdd/commands/make_command_test.dart`
- `test/plugins/tdd/run_command_test.dart`

**Tests to add or update**:

- Planner: a render-type description maps to a plan whose first step is
  `tdd func <id>` and whose last step is `build` (RED first — currently
  unexpressible); every function-intent verb maps; CRUD/entity descriptions
  are unchanged.
- Func command: scaffolds the derived signature + minimal implementation into
  the subject stub; target test goes green; idempotent re-run reports
  `already-implemented`; missing record misfire-stops.
- Make: an unexpressible behavior's output names the verb and the stub path
  with the `implement manually ... then re-run` hint (outcome stays
  `unexpressible`, exit stays 1).
- Run: a feature with one unexpressible unit behavior and later behaviors —
  the run processes ALL behaviors, defers the unexpressible make
  (`[run] U1 make -> deferred (phase 2)`), and stops honestly at the phase-2
  re-attempt naming `U1:make` (not at U1 in phase 1); a make that reports
  `unexpressible` then `ok` on re-attempt completes the whole feature.

## Risks & Considerations

- **Suite-green interaction**: a deferred unit make leaves the suite red, so
  every later `refactor` must defer too (generalized `_hasRedAcceptance`) or
  the preflight hard-stops — the bug #635 mechanism must cover non-acceptance
  RED behaviors.
- **Drift on manual re-run**: after a manual implementation + re-run, `make`'s
  drift check refuses an already-green target test — the operator re-runs
  `zfa tdd run` after implementing manually and the phase-2 re-attempt is
  where `unexpressible` honestly stops; the manual path is by design a
  human-in-the-loop escape hatch, not an automated green.
- **Planner verb over-matching**: the verb list must not swallow existing
  mappings — the entity branch (contains "entity") and CRUD branch
  (contains "crud"/"use case"/"repository"/"service") are checked first, so
  only descriptions matching NEITHER reach the function branch; regression
  tests pin U3-U7 unchanged.
- **Fake-zfa test seam**: run-command tests use scripted fake step binaries;
  the deferral generalization must keep the multi-attempt config semantics
  (first invocation consumes line 1, later invocations the last line) that
  bug #625 tests already rely on.

## Open Questions

- None blocking. The issue's `zfa func`/`zfa method` naming is satisfied by
  `zfa tdd func` (plugin-scoped), consistent with the `zfa tdd wire`
  precedent; the planner emits `tdd func` argv that the real CLI resolves.
