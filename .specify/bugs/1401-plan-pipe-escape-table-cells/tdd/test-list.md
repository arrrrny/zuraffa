# TDD Test List: 1401-plan-pipe-escape-table-cells

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| A1 | piped acceptance prose plans, is escaped on disk, and reads back verbatim through the run-side reader | #1401 | PROVEN |
| U1 | piped FR prose plans, is escaped on disk, reads back verbatim, and re-planning reconciles ids through the escaped file | #1401 | PROVEN |

## Notes

- Artifact: `test/plugins/tdd/commands/plan_command_pipe_escape_1401_test.dart`
- A1 pins the writer-escape contract (`<all\|active\|completed>` on
  disk), the run-side reader round-trip (`<all|active|completed>`
  restored by `TestListReader.read()`), and acceptance-row survival of
  the 4-column gate.
- U1 pins the plan-side reader: a second `zfa tdd plan` re-plans
  through the escaped file with ZERO id drift (no re-numbering) and no
  `expected 4 columns, found 6` refusal — writer and plan's reconcile
  reader agree on the dialect.
