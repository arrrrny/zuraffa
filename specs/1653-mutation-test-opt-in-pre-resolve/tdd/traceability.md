# Traceability: 1653-mutation-test-opt-in-pre-resolve

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:a542fd7c6defac5f86ec1edd226fd6cdf3f6d6142bfadf8c94da13a10b254f41
statements: 14
automated: 14
manual: 0
fr-manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| FR-001 | 91 | - **FR-001**: `PubspecDevDependenciesPatcher` gains `includeMutationTest` | U1 | automated |
| FR-002 | 98 | - **FR-002**: `TddBaselineInit.ensure` gains `mutation` (default false) and | U2 | automated |
| FR-003 | 102 | - **FR-003**: `zfa tdd init` exposes `--mutation` (negatable: false) whose | U3 | automated |
| FR-004 | 105 | - **FR-004**: when the dependency writers newly added entries, init runs the | U4 | automated |
| FR-005 | 110 | - **FR-005**: a resolver run that exits non-zero fails the init sequence | U5 | automated |
| FR-006 | 114 | - **FR-006**: `RefactorCommand` measures the three phases and prints | U6 | automated |
| FR-007 | 118 | - **FR-007**: the refactor cycle-log entry renders | U7 | automated |
| FR-008 | 123 | - **FR-008**: `RefactorPasses` records each pass's wall duration into its | U8 | automated |
| AC-1 | 129 | 1. **Given** an empty pure-Dart project, **When** `zfa tdd init` runs with | A1 | automated |
| AC-2 | 133 | 2. **Given** the same project, **When** `zfa tdd init --mutation` runs, | A2 | automated |
| AC-3 | 136 | 3. **Given** a project where init just added dev_dependencies, **When** | A3 | automated |
| AC-4 | 141 | 4. **Given** a green refactor on a fixture project, **When** the receipt | A4 | automated |
| AC-5 | 145 | 5. **Given** a resolver that exits non-zero during init, **When** init | A5 | automated |
| AC-6 | 148 | 6. **Given** a legacy refactor entry without duration lines, **When** the | A6 | automated |

