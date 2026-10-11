**Template Version**: `zuraffa-1.0`

# Tasks: 1376-verify-kind-trace

Dependency-ordered, MVP-first. T1-T4 are the behavioral MVP (the
red-green loop drives them); T5-T6 are the non-behavioral wiring
(spec-kit artifacts, docs) covered by `/speckit.implement`.

## 1. Kind-trace reader (mvp)

- [ ] **T1** (P1) `behavior_kind_trace.dart` (NEW): parse the
  `// scenario-assertions:` header from a test file's content — accept
  `kind("literal")` cells, `enabled-state("lit")(disabled|enabled)`
  polarity cells, and the bare `sequence` token; validate labels against
  the canonical `ScenarioAssertionClass` labels; unknown tokens degrade
  to `not-traced` with the raw token preserved. Expose the canonical
  order constant (`presence, absence, route-outcome, enabled-state,
  sequence`). Traces: FR-001, FR-002. Depends: —.
- [ ] **T2** (P1) `behavior_kind_trace.dart`: `BehaviorKindTrace.trace()`
  — resolve each registered behavior's test path from the artifact
  registry (relative paths against the audit working directory), read
  the file, parse the header; missing file or missing header → the
  behavior lands in `not-traced`. Return per-behavior kinds +
  `not-traced` ids. Traces: FR-001, FR-002, SC-2. Depends: T1.

## 2. Report surface (mvp)

- [ ] **T3** (P1) `mutation_auditor.dart`: `MutationAuditReport` gains
  `behaviorKindsByBehavior` + `notTracedBehaviors` (default empty — all
  existing constructor sites stay valid); the auditor computes the trace
  once after the scope resolves and populates the full-run reports;
  `toMarkdown()` gains the additive `## Behavior kinds` section
  (per-kind counts in canonical order + per-behavior list + `not-traced`
  bucket; omitted when the scope was empty). Traces: FR-003, FR-006.
  Depends: T2.
- [ ] **T4** (P1) `verify_command.dart`: the stdout summary line gains
  the per-kind counts; the `verdict.v1` envelope `details` gains the
  `behavior_kinds` object (counts + per-behavior + not-traced). Traces:
  FR-004, FR-005. Depends: T3.

## 3. Regression + docs (post-mvp)

- [ ] **T5** (P2) regression guard: the existing mutation-auditor and
  verify suites pass unchanged (gate decisions, exit classes, and the
  pre-#1376 markdown sections are byte-compatible on NOT_ASSESSED
  paths). Traces: FR-006, SC-3. Depends: T3, T4.
- [ ] **T6** (P2) non-behavioral: spec-kit artifacts (spec.md, plan.md,
  tasks.md, tdd/test-list.md, tdd/verification.md) committed under
  `specs/1376-verify-kind-trace/`. Traces: —. Depends: T5.
