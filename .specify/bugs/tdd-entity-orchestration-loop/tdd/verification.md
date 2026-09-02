---
feature: .specify/bugs/tdd-entity-orchestration-loop (bug #829, branch audit, pinned per bug extension TDD mode; the slug named by the task brief had no committed records — the GitHub issue body is the authoritative record)
verdict: PASS_WITH_GAPS
standard: .specify/extensions/tdd/templates/tdd-test-quality-rubric.md
verified_at: 0ce08339
behaviors: 9
proven: 7
likely: 2
test_after: 0
no_test: 0
high_smells: 0
criteria_total: 5
criteria_covered: 5
mutation_score: 7/7 caught # scope: the logic this fix added only (spec_parser.dart, test_list_reader.dart, plan_command.dart, run_command.dart phase 0, make_command.dart trace+gate, generation_planner.dart unit-entity branch, wire_command.dart classification), manual deliberate mutants
mutants_survived: 0
suite: "chunked fast suite 68/68 chunks +2629 −0; make_command_test +33 −2 (2 pre-existing, pristine-identical); run_command_test +38 −1 (1 pre-existing, pristine-identical); scenarios sc_013–sc_020 all green; dart analyze 47 repo-wide = pristine master 47 (touched trees 0); dart format clean on all touched files"
---

# TDD Verification: bug #829 — entity orchestration inside the TDD loop (spec Key Entities → entity create → make → wire)

**Verdict: PASS_WITH_GAPS.** The red→green cycle is real on the real CLI: a
corpus-shaped fixture spec declaring `### Key Entities` reproduced all four
issue signatures pre-fix (R1 plan extracts nothing, R2 no entity dir after a
`result=complete` run, R3 the unit behavior's subject scaffolded as a trivial
`String subject_u1() { return 'subject_u1'; }` with the domain layer
entirely missing, R4 `zfa tdd wire` refusing a func-scaffolded subject with
`unrecognized shape` exit 1), and post-fix the same fixture runs
`[run] phase-0 entity User -> created` → `[run] phase-0 build -> ok` → the
unit behaviors route `entity create -n User → make User → tdd wire U1
--entity User → build`, the run completes with
`lib/src/domain/entities/user/` carrying the spec-declared fields (name,
email — corroborated by the generated `user.zorphy.dart`), and the wired
subject imports and anchors the generated entity. The overwrite hazard
behind remediation 5 was reproduced pre-fix (an entity created with
`email:String` silently lost the field on a second create) and the loop now
reuses instead of regenerating. All five remediation items are covered end
to end, all seven deliberate mutants were killed, and the wire refusal fix
preserves the U-W5 "never rewrite a file you did not generate" contract.
The gaps: no committed test list exists for the bug workflow (ordering
evidence is session-recorded; the commits are atomic, so git history alone
shows LIKELY for two guard behaviors), and the pre-existing failure set is
documented, not fixed, here.

## Test-first evidence

| Behavior | Class | Evidence |
| -------- | ----- | -------- |
| U-829a — a func-scaffolded subject (gen header residue mentions UnimplementedError) is already implemented: `already-wired`, exit 0 (remediation 4) | PROVEN | RED captured verbatim (pre-fix real-CLI probe, this session): `zfa tdd wire: subject at ".../b_903_subject.dart" carries an UnimplementedError in an unrecognized shape — refusing to rewrite a file this command did not generate.`, exit 1. GREEN: the same probe reports `wire: behavior=B-903 outcome=already-wired ... exit 0`; U-829a pins it fast-tier. |
| U-829b — an executable UnimplementedError in a non-stub shape is still refused (U-W5 preserved) | LIKELY | Guard behavior: the refused path's red lineage is U-W5 (pre-existing, still green); the comment-aware classification was written in the same session as the guard, so history cannot show ordering. The mutant pass (M5: revert to raw `contains`) killed the guard — it is load-bearing. |
| U-829c — phase 0 creates every declared entity (with the spec-carried fields) and builds ONCE, before the first gen (remediation 2) | PROVEN | RED: pre-fix the run on the same fixture printed no phase-0 lines and `lib/src/domain/entities` was absent (R2). GREEN: `[run] phase-0 entity User -> created` + `[run] phase-0 build -> ok` land before `[run] B-001 gen` in the argv log; the real-CLI e2e created `user.dart` + codegen artifacts with the declared fields. |
| U-829d — an existing entity is REUSED, never regenerated (remediation 5) | PROVEN | RED: R5 pre-fix probe — `zfa entity create -n User` twice destroyed the `email:String` field. GREEN: with the entity file on disk the driver prints `-> reused`, spawns no `entity create` and no `build`, and the hand-tuned file content is asserted unchanged. |
| U-829e — a failed entity create stops the run honestly (runner-error, stopped_at names phase 0) | LIKELY | New-surface behavior: nothing existed pre-fix to fail, so there is no pre-fix red; the test (scripted config failure) pins exit 2, `result=runner-error`, `stopped_at=phase-0:entity`, and that no behavior was ever driven. |
| U-829f — a feature with no declared entities runs no phase-0 spawn at all | PROVEN | RED: every pre-fix run (the fixture's own, and the corpus shape) printed no phase-0 lines — the invariant is today's behavior on entity-less lists. GREEN: U-829f asserts no `[run] phase-0` output and no `entity create`/`build` argv. |
| U-829g — a unit behavior traced to a declared entity plans entity create → make <Entity> → wire → build (remediation 3) | PROVEN | RED: R3 pre-fix real-CLI run — the same unit behavior routed to `tdd func` and produced `String subject_u1() { return 'subject_u1'; }` with the run green and entity-less. GREEN: the fake-zfa log records `entity create -n User`, `make User`, `tdd wire U1 --entity User`; the e2e subject imports `package:tdd_fixture/src/domain/entities/user/user.dart` and anchors `User`. |
| U-829h — make drops the entity create step when the entity exists (never regenerates over hand-tuned fields) | PROVEN | RED: R5 (the overwrite hazard the loop would otherwise hit on every re-run, including phase-0-created fielded entities). GREEN: `entity <Name> already exists — reuse` printed, no `entity create` in the spawn log, the rest of the pipeline still runs, file content asserted unchanged. |
| U-829i — a unit behavior whose FR traces to no declared entity keeps the func surface | PROVEN | RED: the pre-fix planner routed ALL unit behaviors to func (R3's evidence covers the untraced semantics directly). GREEN: with a `## Key entities` section present but the description naming no declared entity, the spawn log shows `tdd func` and no entity pipeline steps. |

No assertion was weakened: the diff touches only the new bug-829 test
groups, one additive fixture hook in the shared fake zfa (non-driver argv —
`entity create`/`build` spawns — exit 0 with a config-scriptable failure;
unreachable for every pre-existing test because their lists declare no
entities), and the readEntities normalization fix inside the new
`bug 829` group of `test_list_reader_test.dart`. No test was renamed out of
a filter's reach, skipped, or excluded; no coverage/mutation gate was
touched.

## Findings

| # | Severity | Finding | Evidence |
| - | -------- | ------- | -------- |
| 1 | LOW | The bug depends on #827 (per-feature artifact namespacing), which is unmerged. This fix reads entities from the same feature's own `specs/<feature>/tdd/test-list.md` the behaviors come from, so no new cross-feature coupling is introduced and the change is namespacing-neutral — but cross-feature id collisions remain #827's problem | `.specify/bugs/tdd-entity-orchestration-loop/assessment.md` (constraints) |
| 2 | LOW | The make gate parses the `-n <Name>` argv shape of `entity create` steps; an unexpected argv shape fails OPEN to the ungated step (the step spawns and the core command's overwrite semantics apply). All current plan emitters use the exact shape; a future emitter that drifts would silently lose the gate | `lib/src/plugins/tdd/commands/make_command.dart` (`_entityCreateStepName` doc) |
| 3 | LOW | The FR→entity trace is a case-sensitive word-boundary match on the description; FR prose that lowercases the entity name ("a user record") does not trace and keeps the func surface. Conservative by design (fewer false positives), but a real corpus spec phrased that way gets no orchestration | `lib/src/plugins/tdd/commands/make_command.dart` (`_tracedEntityFor`) |
| 4 | LOW | A run killed BETWEEN a phase-0 `entity create` and its `zfa build` resumes with the entity `reused` and the build `skipped` (nothing created) — the codegen artifacts are then first produced by the first behavior's terminal build step rather than phase 0. Honest, self-healing, but the phase-0 build guarantee is per-invocation, not cross-invocation | `lib/src/plugins/tdd/commands/run_command.dart` (`_runEntityPhaseZero`, created==0 branch) |
| 5 | LOW | The workflow stated records exist at `.specify/bugs/tdd-entity-orchestration-loop/`; no committed records existed on any ref at fix time (verified across 266 remote branches). `issue.md` transcribes the GitHub issue body verbatim and `assessment.md` restates its Required section — no re-triage was performed | `git log --all -- .specify/bugs/` (no 829 records); issue #829 body |
| 6 | LOW | Pre-existing failures pre-date this branch and are intentionally not remediated here (single-purpose PR): bug 657 verb-naming + spec 052 A11/U17 SC-004 in `make_command_test.dart` (both verified failing on pristine `0ce08339` via stash in this session; pristine full file −2 → this tree +33 −2, the same 2 plus this fix's 3 passing tests) and bug #691 in `run_command_test.dart` (verified failing on pristine via stash; pristine full file −1 → this tree +38 −1, the same 1 plus this fix's 4 passing tests; one additional 734v2 failure appeared in one full-file run and did not reproduce on re-run or in isolation — timing flake, not attributable). Also pre-existing on master: the `examples/mcp_demo/lib/src/mcp/tools.dart` format drift (excluded from this PR) | Pristine stash runs + fixed-tree runs in this session |

## Mutation results (deliberate mutants, manual — no mutation tool in profile)

Scope: the logic this fix added only. One small change each, run against the
behavior's own test, expected failure, restored exactly (backup-copy
restore), suite re-verified green after the pass.

| Mutant | Behavior | Survived | Judgment |
| ------ | -------- | -------- | -------- |
| `make_command.dart` `_tracedEntityFor` returns null unconditionally (trace dropped) | U-829g | No | Killed by U-829g — the entity pipeline argv must appear in the spawn log |
| `make_command.dart` `_gateExistingEntityCreateSteps` never drops a create step | U-829h | No | Killed by U-829h — no `entity create` may appear when the entity exists |
| `run_command.dart` phase 0 skips the `zfa build` spawn (created>=0 early return) | U-829c | No | Killed by U-829c — the build line and its argv position are pinned |
| `run_command.dart` phase 0 drops the reuse check (always spawns create) | U-829d | No | Killed by U-829d — reuse must not spawn; file content pinned |
| `wire_command.dart` `_hasExecutableUnimplementedError` reverts to raw `contains` (the bug) | U-829a | No | Killed by U-829a — the func-residue subject must be `already-wired`, not refused |
| `generation_planner.dart` unit-entity branch drops the `make <Entity>` step | U-829a (planner) | No | Killed by the planner test — the 4-step pipeline shape is pinned exactly |
| `spec_parser.dart` field extraction returns empty always | Key Entities group | No | Killed by the parser tests — backticked field pairs must parse |

7/7 killed, 0 survived, 0 equivalent. Sampled behaviors: the trace resolver,
the idempotency gate, phase-0 create/build/reuse/failure, the wire
classification, the pipeline shape, and the field extraction — the full
surface this fix added; not a whole-repo mutation score.

## Traceability

| Criterion (issue Required item) | Tests | End to end |
| ------------------------------- | ----- | ---------- |
| 1. plan extracts Key Entities (entity → fields) | `spec_parser_test` bug-829 group; `plan_gen_contract_test` bug-829 group; `test_list_reader_test` bug-829 group | Yes (real-CLI R1 flip: section absent → present with `User \| name: String, email: String`) |
| 2. run phase 0: idempotent entity create + build before behaviors | `U-829c`, `U-829d`, `U-829e`, `U-829f` | Yes (real-CLI e2e: phase-0 lines before first gen; entity dir + codegen artifacts on disk) |
| 3. entity-traced unit behaviors route to the entity pipeline | planner `U-829a`/`U-829b`; make `U-829g`, `U-829i` | Yes (real-CLI e2e: wired subject referencing the generated entity; run completes) |
| 4. wire shape detection accepts valid stubs | wire `U-829a`, `U-829b`; U-W1–U-W5 regression set | Yes (real-CLI R4 flip: `unrecognized shape` exit 1 → `already-wired` exit 0) |
| 5. idempotent entity reuse — never overwrite | `U-829d`, `U-829h`; mutants M2/M4 | Yes (R5 pre-fix overwrite repro; post-fix reuse asserted at both spawn sites) |

Untested criteria: none. Tests tracing to nothing: none.

## What was not audited

- The slow tiers the chunked fast suite excludes by design
  (`benchmark`, `property`, `integration`-tagged suites beyond those named
  above) were not run on this branch; `--preset=all` runs were scoped to
  the files this fix touches (`make_command_test.dart`,
  `run_command_test.dart`) and the run-driver scenarios
  (`sc_013`–`sc_020`, all green).
- sc_001–sc_012 and the remaining plugin suites ran only through the
  chunked fast suite, not individually under `--preset=all`.
- Mutation was a manual deliberate-mutant sample over the added logic
  (7 mutants), not a tool-generated score; equivalent-mutant judgment is
  therefore not exhaustive.
- The core `zfa entity create` overwrite semantics (R5's raw behavior) are
  master behavior outside this fix's scope; only the loop's use of the
  command was audited.
- #827's namespacing implementation was not audited (unmerged); the
  dependency is recorded, not verified.
