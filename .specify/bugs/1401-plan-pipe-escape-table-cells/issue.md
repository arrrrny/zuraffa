# Issue #1401 (verbatim)

- **Number**: 1401
- **State**: open
- **Author**: arrrrny
- **Created**: 2026-09-09T07:57:22Z
- **URL**: https://github.com/arrrrny/zuraffa/issues/1401
- **Labels**: 

---

## Repro

1. Author a spec whose FR text contains a literal pipe, e.g.:
   ```
   - **FR-007**: The CLI MUST expose `todo filter <all|active|completed>` ...
     traces: CliCommandParser, XrayBridgeClient.invokeAction
   ```
2. `zfa tdd plan <feature>` — succeeds, writes `tdd/test-list.md` (and `04-ENGINE.md`) with the FR description interpolated VERBATIM into a markdown table row:
   ```
   | U7 | The CLI MUST expose `todo filter <all|active|completed>` ... | FR-007, ... | PENDING |
   ```
   (6 cells instead of 4)
3. `zfa tdd run <feature>` — dies before any behavior:
   ```
   zfa tdd run: test-list.md line 38: expected 4 columns (id/behavior/traces/state), found 6: "| U7 | ..."
   run: feature=xray-cli result=runner-error pending=0 red=0 green=0 done=0
   ```

## Root cause

`lib/src/plugins/tdd/commands/plan_command.dart` interpolates `b.description` into pipe-table rows without escaping (lines ~1170, ~1202, ~1216, ~1244; the meta-index reconcile reader at ~line 436 splits cells on `|` the same way). The writer and reader are consistent only when no FR/AC text ever contains a pipe — nothing in the spec-parser grammar forbids pipes in FR prose, so plan emits a file run refuses. Plan/run disagree on the validity of plan's own output.

## Expected

The plan writers escape `|` as `\|` inside table cells (and the readers unescape), so FR/AC text may contain literal pipes. Fail-fast at PLAN time with a remedy would also be acceptable, but silently writing a file the runner rejects is the worst of both.

## Workaround

Reword FR/AC text to avoid literal `|` (e.g. `<all, active, completed>`).

Found 2026-09-09 while running the xray-cli spec cycle (zfa binary build 583d711d, branch fix/1351-gen-flutter-test-import).
