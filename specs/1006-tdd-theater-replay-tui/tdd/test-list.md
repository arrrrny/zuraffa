---
feature: 1006-tdd-theater-replay-tui
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 4
planned_at: 1006-tdd-theater-replay-tui
updated_at: 1006-tdd-theater-replay-tui
suite_baseline: green
---

# Test List: `zfa tdd theater` — read-only replay TUI for the TDD journal

Baseline: `dart test test/plugins/tdd/` at branch point — fast tier green
(chunked runner). Cycle-log fixtures are seeded through the REAL
`CycleLog.append` writer (schema-1 chain lines byte-exact by construction);
receipts are seeded through the REAL `GenerationReceipt` JSON shape
(`proof.v1`). The TUI is driven through nocterm's `NoctermTester` (the same
harness `test/plugins/tui/` uses); command behaviors drive the real CLI entry
point in-process (`CliRunner.runCapturing`, the sc_001–sc_012 pattern). No
`dart test` is spawned inside fixtures (kernel-cache safe).

## Outer loop: acceptance behaviors

The 4 A-rows trace the 4 user stories in `spec.md`; the `traces` column
names the story each row covers. A-rows drive the real CLI entry point and
the real nocterm component tree.

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1  | `zfa tdd theater 004-login-ui` opens a three-pane read-only TUI: left pane renders one card per registered behavior (id, criterion, description, proof status), right pane renders the cycle-log timeline in file order, bottom renders the live status line; every registered behavior is rendered | US1 | example | DONE | `test/plugins/tdd/theater/theater_screen_test.dart::A1: the three panes render every behavior and the timeline` |
| A2  | Clicking a behavior card expands it inline and shows its receipt in the right pane: the derived `action:` line (`satisfied` when green evidence exists), the `evidence:` line (green test + exit + timestamp) and the `file:` line (registered subject path + #807 receipt action/bytes/sha256 when covered) | US2 | example | DONE | `test/plugins/tdd/theater/theater_screen_test.dart::A2: clicking a behavior shows the receipt` |
| A3  | Clicking a timeline cycle shows the cycle's evidence diff in the right pane: recorded command, exit code, criterion, test, the captured output block and the chain hash | US2 | example | DONE | `test/plugins/tdd/theater/theater_screen_test.dart::A3: clicking a cycle shows the diff` |
| A4  | Pressing `[?]` with a behavior selected opens the classifier verdict overlay — kebab-case classification label, remediation hint, failing-assertion evidence when recorded — and any key closes it | US3 | example | DONE | `test/plugins/tdd/theater/theater_screen_test.dart::A4: [?] opens the classifier verdict` |
| A5  | On non-TTY stdout the command refuses to start the TUI with an actionable message and exits 1, printing the machine summary `theater: feature=<f> behaviors=<n> cycles=<m> receipts=<k> result=non-tty` as the final stdout line | US1 | example | DONE | `test/plugins/tdd/commands/theater_command_test.dart::A5: non-TTY refuses with the summary line` |
| A6  | The command is read-only end to end: the whole fixture project tree (including `.zfa/` and `specs/`) is byte-identical before and after a non-TTY invocation | US4 | example | DONE | `test/plugins/tdd/commands/theater_command_test.dart::A6: the theater writes nothing` |
| A7  | An unknown feature id exits 1 with the id named; a feature with a registry but no cycle-log still loads (behaviors render `pending`, cycles 0) and prints `result=non-tty` on non-TTY; a feature with no registry exits 1 naming the missing artifact | US4 | example | DONE | `test/plugins/tdd/commands/theater_command_test.dart::A7: unknown / pending / missing-registry paths fail or load honestly` |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/services/theater_data.dart` (snapshot loading)

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1  | Behaviors load from the registry in file order with criterion, description, test/subject paths, and proof status derived from the cycle-log (green > red > pending); a behavior with no cycle-log entry is `pending`, never an error | US1 | example | DONE | `test/plugins/tdd/theater/theater_data_test.dart::U1: behaviors load with cycle-derived status` |
| U2  | Receipts are read from BOTH layouts: `.zfa/receipts/<feature>/*.json` per-feature documents, and flat `.zfa/receipts/*.json` documents attributed by matching recorded file paths against the feature's registered subject/test paths; latest-wins per path; corrupted JSON documents are skipped, never fatal | US1 | example | DONE | `test/plugins/tdd/theater/theater_data_test.dart::U2: receipts load from per-feature and flat layouts, latest-wins` |
| U3  | Cycle parsing captures the full journal row: kind, classification, evidence, criterion, test, command, exit, timestamp, the fenced output block, green generation steps and refactor actions, and the schema/prev-hash/hash chain lines; prose sections without `- behavior:` are skipped | US2 | example | DONE | `test/plugins/tdd/theater/theater_data_test.dart::U3: the cycle parser captures the full journal row` |
| U4  | The behavior receipt is derived honestly: `action: satisfied` with the green evidence line when green evidence exists, `action: red` with the classification when only red evidence exists, `action: pending` with no recorded evidence; the `file:` line carries the #807 action/bytes/sha256 exactly when a receipt covers the subject | US2 | example | DONE | `test/plugins/tdd/theater/theater_data_test.dart::U4: receipts derive action/evidence/file honestly` |
| U5  | The classifier verdict maps the cycle-log classification (camelCase `FailureClass` names) onto the `RedClassification` vocabulary (kebab-case label + remediation hint) and carries the recorded failing-assertion evidence; an unmapped or absent classification renders the raw label with no invented remediation | US3 | example | DONE | `test/plugins/tdd/theater/theater_data_test.dart::U5: the classifier verdict maps to RedClassification vocabulary` |
