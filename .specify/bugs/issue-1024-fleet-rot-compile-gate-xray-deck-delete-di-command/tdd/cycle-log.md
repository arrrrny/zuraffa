# TDD Cycle Log — issue #1024 (compile-gate xray deck + delete dead di_command.dart)

## Baseline

- Branch `fix/1024-xray-deck-compile-gate-delete-di-command` @ `77e69f24`, Dart SDK 3.13.3.
- `dart analyze` repo-wide: 345 issues (31 errors all in `examples/todo_tdd/`,
  pre-existing; 0 in `lib/`/`test/`).
- `tools/run_tests_chunked.sh` fast suite: green (74/74 chunks).
- Bug records: `.specify/bugs/issue-1024-fleet-rot-compile-gate-xray-deck-delete-di-command/{issue.md,assessment.md}`
  (records were not pre-committed on any branch; created from the GitHub issue
  body + code verification — see assessment.md provenance note).

## Cycle 1 — xray deck emits the real Control Deck API

**RED** (`tdd/red-evidence.txt`):
The existing pin at `test/commands/xray_deck_cli_test.dart:69`
(`contains('XRayControlDeckRegistry.registerEntries')`) was GREEN while the
emitted deck was broken — the string-match pinned the bug. Real reproduction:
generated a deck with the unfixed emitter into a temp sandbox and ran
`dart analyze` on it → **7 errors** (dead `src/presentation/xray/` import;
undefined `XRayControlDeckRegistry`; undefined `XRayMockEntry`/`XRayMockType`
(missing imports); `kReleaseMode` undefined without the flutter import;
non-const list element). Exit criterion (output passes analyze) was RED.

**GREEN** (`tdd/green-evidence.txt`):
- Emitter fix (`lib/src/commands/xray_deck_command.dart::_generateDeckFile`):
  - emit `XRayControlDeck.instance.registerEntries(const [...])`
    (real API: `xray_control_deck.dart:37,70`);
  - imports resolve: `src/plugins/xray/{xray_control_deck,xray_mock_entry,xray_mock_type}.dart`
    + `src/core/xray_config.dart`;
  - pure-Dart release guard `kXrayReleaseMode` (drops `package:flutter`);
  - YAML `description:` → doc comment (`XRayMockEntry` has no such parameter);
  - unrecognized `type:` → `XRayMockType.unknown` (matches
    `XRayMockType.fromString`) so garbage input cannot produce a non-compiling deck.
- Compile gate test (`xray_deck_cli_test.dart`): generates a deck, builds a
  minimal pure-Dart sandbox package (path dep on the repo), runs
  `dart pub get --offline` + `dart analyze`, asserts exit 0. Replaces the
  broken string-match pin.
- Proof receipt per deck generation: `proof.v1` record written to
  `<root>/.zfa/receipts/` via `ReceiptStore`, sha256 + snapshot of the deck
  bytes; output pins assert schema/command/target/api.
- Updated stale pins to the corrected output; suite green (7/7).

**REFACTOR**: none required (plan step 4).

## Cycle 2 — delete dead di_command.dart

- `git rm lib/src/commands/di_command.dart` (427 LOC; `class DiCommand` had
  zero external references — grep evidence in red-evidence.txt).
- `zfa di create Foo` verified in a sandbox in both modes:
  `--no-entity` → `foo_usecase_di.dart` + barrels + service_locator;
  entity-based → `get_foo_usecase_di.dart` / `update_foo_usecase_di.dart`.
  Routing untouched: `DiPlugin.createCommand()` → `ModularDiCommand`.
- Grep `\bDiCommand\b` (excl. `ModularDiCommand`) across lib/test/bin → 0 hits.

## Verify

- `dart analyze`: 345 issues — byte-identical count to baseline; 0 errors
  outside the pre-existing `examples/todo_tdd/`.
- `tools/run_tests_chunked.sh` (resumable mirror, 74/74 chunks): all passed,
  no new failures.
- `dart format .`: 0 changed → `git diff --stat` shows no formatting diffs.
- Mutation sampling (4 mutants, all KILLED — `tdd/mutation-evidence.txt`):
  M1 dead registry name, M2 dropped type sanitizer, M3 dropped description
  comment, M5 receipt no-op. Working tree restored byte-identical after each.
