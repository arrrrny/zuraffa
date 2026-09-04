# Feature Specification: Inert-Stub Red — Certify Widget Finders as the RED Surface

**Feature Branch**: `071-inert-stub-red`

**Created**: 2026-09-03

**Status**: Draft

**Input**: User description: "[TDD-136] inert-stub red: certify widget finders as the RED surface — authored assertions must be observed failing before they may pass" (GitHub issue #959, arrrrnny/zuraffa)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Red is certified on the authored assertions, not a guard (Priority: P1)

A developer drives the TDD loop for a widget behavior (a piece of on-screen interface). Today, when the behavior is not yet implemented, the red run stops at a single guard assertion — "the subject did not fail with an unimplemented error" — and aborts there because the unimplemented subject throws. The assertions the developer (or generator) actually authored about the screen — that a given label appears, that a widget is present — never execute at red time. They go from never-run to passing the moment an implementation lands, without ever being observed failing ("born green"). Red certification is therefore an honor system, and the project's UI coverage claim rests on assertions no one ever saw fail.

With this feature, the red harness for widget behaviors substitutes an inert-but-valid stand-in for the missing implementation: a widget that renders successfully but displays none of the expected content. The red run then proceeds past the guard, pumps the stand-in into the harness, and executes every authored assertion against it. Because the stand-in shows no expected content, each authored assertion that genuinely inspects the interface fails — and that failure is what certifies red. When the real implementation arrives, the same assertions pass. Every authored assertion has now been observed failing before it was allowed to pass.

**Why this priority**: This is the core value of the feature. Without assertion-level red certification, red/green discipline in the widget lane is theater — coverage numbers are not backed by proven-failable assertions. Everything else in the issue depends on this mechanism existing.

**Independent Test**: Generate the widget-lane test for one unimplemented behavior, run the red phase, and confirm the failure report names an authored interface assertion as the cause of red (not only the unimplemented guard). Delivers machine-proof that authored assertions can fail.

**Acceptance Scenarios**:

1. **Given** a widget behavior with no implementation, **When** the red phase runs, **Then** the run reports red with the verdict identifying a specific authored interface assertion as the failing evidence.
2. **Given** the same behavior once implemented, **When** the test runs again unchanged, **Then** all authored assertions pass (green) with zero edits to the assertions.
3. **Given** an authored assertion that checks a specific on-screen label, **When** red runs against the inert stand-in, **Then** that assertion fails because the stand-in does not display the label.

---

### User Story 2 - Scaffolded, vacuous tests can never be certified red (Priority: P2)

A test scaffold (a placeholder with marker text where assertions will be authored later) can currently slip through red verification via a "scaffold gate" that is only a string check — honor-system at the exact moment judgment matters most. Worse, some authored assertions are vacuous: they pass regardless of what is on screen (for example, "the built view widget appears in the tree" is satisfied by any widget, even an empty box).

With this feature the scaffold gate becomes mechanical. Against the inert stand-in, a vacuous assertion passes (it passes against anything), so the run cannot produce a failure attributable to it, the verdict is "not red", and the generation workflow refuses to proceed until real, content-inspecting assertions exist. A vacuous test becomes un-greenable rather than merely discouraged.

**Why this priority**: It closes the escape hatch that lets born-green assertions into the suite. It is enabled by Story 1's mechanism but adds independent workflow value (refusal of unverifiable tests), so it ships second.

**Independent Test**: Take a scaffolded test whose only view assertion is vacuous, run red verification, and confirm the verdict is "not red" and the workflow refuses to proceed. Delivers a guarantee that no assertion-free test is counted as red.

**Acceptance Scenarios**:

1. **Given** a test containing only vacuous interface assertions, **When** red verification runs against the inert stand-in, **Then** the verdict is not-red (the vacuous assertions pass, so nothing certifies red).
2. **Given** a scaffolded test still containing its placeholder marker, **When** red verification runs, **Then** the verdict is not-red and the workflow refuses to proceed until real assertions are authored.
3. **Given** a test whose assertions genuinely inspect expected content, **When** red verification runs, **Then** the verdict is red and the workflow proceeds to implementation.

---

### User Story 3 - Red verdicts are self-explanatory (Priority: P3)

A developer reading a red verdict can see exactly which assertion failed and why the run counts as red. The classification names the failing assertion (e.g., "expected label 'Home' on screen; stand-in shows nothing") rather than a generic "test failed" outcome. This makes the verdict auditable: a reviewer can distinguish a genuine assertion-level red from a guard-level red or a crash.

**Why this priority**: Improves trust and debuggability of the mechanism from Stories 1–2 but does not change what is enforced.

**Independent Test**: Run red on a behavior whose authored assertion targets a missing label; read the verdict and confirm it identifies that assertion by name and reason.

**Acceptance Scenarios**:

1. **Given** a red run failed by an authored assertion, **When** the verdict is produced, **Then** the classification names the specific failing assertion and states it is the red evidence.
2. **Given** a red run that failed only at the secondary guard (no assertions executed), **When** the verdict is produced, **Then** the classification distinguishes this from assertion-level red.

---

### User Story 4 - Existing error-capture protection remains in force (Priority: P4)

The current protection — capturing the "unimplemented" failure and asserting the subject no longer throws it — continues to work exactly as before as a secondary guard underneath the new mechanism. Developers relying on it see no behavior change; the new inert-stand-in path runs in front of it.

**Why this priority**: It is a compatibility guarantee, not new capability; it must hold but requires no design decisions.

**Independent Test**: With the inert-stand-in path enabled, force a subject that still throws the unimplemented error and confirm the existing error-capture behavior still reports as it did before this feature.

**Acceptance Scenarios**:

1. **Given** a subject that still raises the unimplemented error at red time, **When** the harness runs, **Then** the existing error-capture guard reports the failure as it did before this feature existed.

---

### Edge Cases

- What happens when an authored assertion targets content that only exists in page chrome outside the view under test (e.g., a navigation-bar label that also appears in the view's expectations)? The red run still certifies red against the stand-in, but the assertion could later be satisfied by chrome rather than the view; full target-isolation of assertions is out of scope for this feature (see Assumptions).
- What happens when the implementation renders the expected content but an assertion is genuinely wrong (e.g., misspelled label)? The test stays red after implementation — correct behavior; the red evidence names the failing assertion so the developer can fix the assertion, not the implementation.
- What happens when a widget behavior test contains a mix of vacuous and real assertions? Red is certified by the real ones; the vacuous ones add nothing but do not block red.
- What happens when the stand-in itself fails to render (harness defect)? The run must not be misreported as assertion-level red; the verdict distinguishes harness failure from assertion failure.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The red harness for widget-lane behavior tests MUST use an inert-but-valid stand-in as the red surface — a renderable widget that satisfies the interface type but displays none of the authored expectations — instead of aborting at the unimplemented error.
- **FR-002**: Red certification MUST execute all authored view assertions at red time; the run MUST NOT stop at the first guard assertion when the stand-in renders successfully.
- **FR-003**: The red verdict classification MUST identify the specific authored assertion whose failure certifies red.
- **FR-004**: A test whose view assertions all pass against the inert stand-in (vacuous or scaffold-placeholder assertions) MUST be classified not-red, and the generation workflow MUST refuse to proceed to implementation for it.
- **FR-005**: The existing unimplemented-error capture path MUST remain active as a secondary guard for cases where the subject still throws.
- **FR-006**: When the real implementation is supplied, the previously red test MUST pass with zero modifications to the authored assertions.
- **FR-007**: A red verdict MUST distinguish assertion-level red (an authored assertion failed against the stand-in) from guard-level red (only the secondary guard fired) and from harness failure.
- **FR-008**: The placeholder marker left by test scaffolding MUST continue to force a not-red verdict until removed and replaced by real assertions.

### Key Entities *(include if feature involves data)*

- **Widget behavior test**: A test asserting the rendered outcome of one unimplemented interface behavior; contains a guard assertion plus authored view assertions.
- **Inert stand-in**: A valid, renderable widget with no content of its own; the red-time substitute for the missing implementation.
- **Red verdict**: The classified outcome of a red run — assertion-level red, guard-level red, not-red, or harness failure — including the name of the certifying failing assertion when present.
- **Vacuous assertion**: An assertion satisfied by any rendered output regardless of content; cannot certify red.
- **Scaffold marker**: Placeholder text left in generated tests signaling assertions are not yet authored; forces not-red.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of authored view assertions in a generated widget-lane test are observed failing at red time before any of them may pass; zero born-green assertions remain in the widget lane.
- **SC-002**: Every widget-lane red verdict names the specific failing assertion that certifies red, in 100% of assertion-level red runs.
- **SC-003**: A scaffolded or vacuous-only test is refused (verdict not-red, workflow halts) in 100% of attempts; zero vacuous-only tests reach green.
- **SC-004**: When an implementation lands, previously red widget tests pass without any edit to authored assertions (zero assertion rewrites at green time).
- **SC-005**: Reviewers can distinguish assertion-level red, guard-level red, and harness failure from the verdict alone, without reading the test source.

## Assumptions

- The inert stand-in is chosen to be maximally inert: it renders successfully but intentionally displays none of the content any reasonable authored expectation would target.
- Scope is the widget lane of behavior test generation and red verification; non-widget lanes keep their existing red mechanics.
- The inert stand-in becomes the default red surface for widget-lane generation; a verification mode that certifies finder-level red without regenerating tests is acceptable as a convergence path, provided both reach the same mechanical verdict.
- The string-based scaffold gate (issue #912) is retained but demoted to a backstop; the mechanical not-red refusal becomes the primary enforcement.
- Wrong-target assertions (finders satisfied by page chrome rather than the view under test) are mitigated — they fail against the stand-in at red time — but full target-isolation is out of scope for this feature.
- Existing generated tests are not retroactively modified; the mechanism applies to newly generated and newly verified widget-lane tests.
