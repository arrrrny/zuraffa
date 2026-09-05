# Traceability: 0969-tdd-a-plus-upgrade

Coverage proof for `zfa tdd plan` (bug #846): every FR/AC requirement statement maps to a behavior row or an explicit manual declaration. Verify re-checks the hash — a spec edited after plan is drift (exit 3, re-plan required).

<!-- tdd:traceability
spec-hash: sha256:61195833746849c09e9e46e9bff4a81462bbb427982af3d4868475ce054fb89d
statements: 13
automated: 13
manual: 0
open-gaps: 0
-->

| requirement | line | statement | behavior | status |
| --- | --- | --- | --- | --- |
| AC-1 | 14 | 1. **Given** a feature driven through the TDD loop **When** an agent | A1 | automated |
| AC-2 | 19 | 2. **Given** a consumer needs to pin the machine contract **When** it | A2 | automated |
| AC-3 | 22 | 3. **Given** a full plan→gen→verify-red→make cycle **When** every | A3 | automated |
| AC-4 | 27 | 4. **Given** a receipted artifact was hand-edited **When** `zfa tdd | A4 | automated |
| AC-5 | 31 | 5. **Given** a documentation consumer **When** it reads openwiki **Then** | A5 | automated |
| FR-001 | 37 | - **FR-001**: Every `zfa tdd` subcommand accepts `--json` and, when the | U1 | automated |
| FR-002 | 41 | - **FR-002**: The envelope schema is `verdict.v1` with the keys | U2 | automated |
| FR-003 | 46 | - **FR-003**: A test asserts the exact envelope schema for at least | U3 | automated |
| FR-004 | 49 | - **FR-004**: `zfa tdd verdicts --schema` prints the envelope schema | U4 | automated |
| FR-005 | 51 | - **FR-005**: The generation verbs gen, make, view, func, wire and | U5 | automated |
| FR-006 | 56 | - **FR-006**: `zfa tdd verify` runs the proof preflight (`zfa proof | U6 | automated |
| FR-007 | 59 | - **FR-007**: The last-line machine grammar is unified: exactly one | U7 | automated |
| FR-008 | 63 | - **FR-008**: openwiki `cli.md` documents the tdd command table and | U8 | automated |

