# Fix report — Issue #1469

Branch: `fix/1469-journal-flush-to-disk` (one PR, closes #1469).
TDD mode: red → green recorded in `tdd/cycle-log.md` / `tdd/verification.md`.

## What changed and why

1. **`lib/src/plugins/tdd/services/journal.dart` — one behavioral line.**
   `await flushToDisk(tmp);` inserted between the journal `writeAsString` and
   the `rename`, with a provenance comment (#828 discipline, #1469 gap):

   ```dart
   const encoder = JsonEncoder.withIndent('  ');
   final tmp = File('${file.path}.tmp');
   await tmp.writeAsString('${encoder.convert(journal)}\n');
   // Bug #828 gave run_state_store and artifact_registry the crash-safe
   // write discipline; bug #1469 extends it here: fsync the tmp file
   // before the rename, so a power loss between writeAsString and rename
   // cannot leave a truncated journal.json behind.
   await flushToDisk(tmp);
   await tmp.rename(file.path);
   ```

2. **Same file — one import.** `import 'run_state_store.dart' show flushToDisk;`
   Dart imports are not transitive: journal.dart already imports
   `artifact_registry.dart`, but that does not expose run_state_store's
   symbols. The scoped `show` narrows the added surface to exactly the one
   helper (no RunState/exception symbols leak into journal.dart's namespace).

Nothing else changed: journal schema, entry JSON shape, cycle-log writing,
the schema-file write path, and both sibling stores are untouched
(`git diff --stat origin/master...HEAD` = the two files).

## Constraints honored

- Single behavioral call added — yes; the diff is one await + one import +
  a comment in lib/.
- No journal schema/entry-format change — yes.
- `dart analyze` no new warnings — yes: changed files analyze clean; full-repo
  issue count 112 on the branch vs 112 on origin/master baseline (0 new).
- No other store touched — yes.

## Verification (all run on this branch, Dart 3.13.3)

- RED: U2.5 failed pre-fix with the exact missing-fsync reason
  (`red-evidence.md`).
- GREEN: U2.5 passes; whole `journal_test.dart` 18/18; journal + sibling
  store suites 47/47; `unified_journal_commands_test` is slow-tagged
  (excluded by dart_test.yaml policy), theater journal integration 3/3.
- Full-repo `dart analyze .`: 112 issues, identical count and paths to the
  origin/master baseline — 0 new.
- `dart format`: both changed files format-stable. Note: master itself has
  one pre-existing unformatted file (`tool/generate_openwiki_cli_docs.dart`);
  left untouched to keep the diff single-scope.
- Chunked fast suite (kernel cache cleaned between chunks, per
  dart_test.yaml disk policy): 30 chunks including the entire
  `test/plugins/tdd` subtree, `test/cli`, `test/commands`, `test/regression`,
  `test/engine`, `test/mcp`, `test/zap`, `test/state`, `test/domain`,
  core samples — all "All tests passed" (~1,500 tests). Two chunks
  (`test/plugins/tdd/scenarios`, `test/tdd/077-make-engine-preset`)
  contain only slow-tagged suites and are correctly excluded by the
  default tier.
