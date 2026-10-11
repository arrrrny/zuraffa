**Template Version**: `zuraffa-1.0`

# Tasks: 1344-agent-runtime-barrel-collisions

Dependency-ordered, MVP-first. T1-T3 are the behavioral MVP (the red-green
loop drives them: each has a failing test BEFORE its implementation); T4-T5
are the non-behavioral wiring (barrel restructure + cross-artifact
consistency) covered by `/speckit.implement`.

## 1. Behavioral MVP — collision surface (mvp)

- [x] **T1** (P1) Add `test/fixtures/agent_collision_consumer_fixture.dart`:
      a consumer-simulation library declaring the same-named domain entities
      zuraffa_agent owns — `LlmClient` (class), `RiskTier` (enum),
      `ToolResult` (class) — plus `StatefulAgent`, `MissionTrace`,
      `MissionBudget` to cover the wider agent-domain collision class, each
      with a fixture marker assertion surface. Traces: FR-003, SC-3.
      Depends: —.
- [x] **T2** (P1) Add `test/agent/default_barrel_collision_test.dart`:
      imports BOTH `package:zuraffa/zuraffa.dart` AND the consumer fixture
      and REFERENCES the six names, asserting fixture-owned resolution.
      MUST fail to compile against the current barrel (ambiguous imports)
      — recorded red evidence. Traces: FR-003, SC-3. Depends: T1.
- [x] **T3** (P1) Add `test/agent/agent_barrel_access_test.dart`: imports
      `package:zuraffa/agent.dart`, references `LlmClient`, `RiskTier`,
      `ToolResult`, `StatefulAgent`, `AgentKernel` (runtime-owned
      resolution), and asserts type identity with direct deep imports
      (`package:zuraffa/src/agent/runtime/llm_client.dart`). MUST fail
      before `lib/zuraffa/agent.dart` exists — recorded red evidence.
      Traces: FR-004, SC-4. Depends: —.

## 2. Barrel restructure (non-behavioral)

- [x] **T4** (P1) `lib/zuraffa.dart`: remove the four `src/agent/**` export
      sites (ui_render, kernel, policy shell, runtime plugin) and their
      section comments; leave a pointer comment to the dedicated agent
      barrel; verify no `agent/` path string remains in the file
      (SC-1). Traces: FR-001, SC-1. Depends: T2, T3 (red recorded).
- [x] **T5** (P1) Add `lib/zuraffa/agent.dart`: re-home the four export
      sites verbatim with `../src/agent/...` relative paths and their hide
      clauses unchanged; document the gating rationale (material/widgets
      split precedent, ecosystem collision root cause). Traces: FR-002,
      FR-004, SC-2. Depends: T4.

## 3. Guard + verification wiring (non-behavioral)

- [x] **T6** (P1) Add `test/agent/default_barrel_gating_test.dart`: source-
      level guard encoding SC-1 (zero `agent/` matches in
      `lib/zuraffa.dart`) and SC-2 (`lib/zuraffa/agent.dart` exists and
      carries the four former sites). Green only after T4+T5. Traces:
      FR-001, FR-002, SC-1, SC-2. Depends: T4, T5.
- [x] **T7** (P2) Run the targeted verification pass: `dart analyze` on the
      changed barrel files + the new tests; run the three new test files +
      the existing barrel guard test (`test/pubignore_export_guard_test.dart`)
      to prove the non-agent barrel surface is unchanged; `dart format .`
      with zero remaining diffs. Record red/green evidence in
      `tdd/verification.md`. Traces: FR-005, SC-5. Depends: T4, T5, T6.

## /speckit.analyze — cross-artifact consistency

- spec.md acceptance scenarios 1-4 map 1:1 to FR-001..FR-005 and
  SC-1..SC-5; tasks T1-T7 cover every FR (FR-001: T4+T6; FR-002: T5+T6;
  FR-003: T1+T2; FR-004: T3+T5; FR-005: T7) — no orphan requirements, no
  task without a trace, no drift between the plan's surface list and the
  tasks' file list. Hard constraints re-checked: no task touches
  `lib/src/agent/**` or zuraffa_agent.
