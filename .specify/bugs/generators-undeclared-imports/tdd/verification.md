# TDD Verification — bug #1265 (`generators-undeclared-imports`)

Hand-authored verification record for the bug-fix PR
`fix/1265-generators-undeclared-imports`. Every number below is from an
actually executed command in this session (Dart SDK 3.13.2, Linux x64,
2 vCPU / 4.1 GB). Nothing here is projected or copied from a run that did
not happen.

## Machine gate — dispatch attempt, verbatim

Per the `/speckit.tdd.verify` contract the deterministic engine was
dispatched first:

```
$ zfa tdd verify --feature generators-undeclared-imports
mutation: gate=not_assessed killed=0 survived=0 timed_out=0 mutation_was_run=false
❌ mutation audit gate: not_assessed (no behavior artifacts registered)
See specs/generators-undeclared-imports/tdd/verification.md for the full report.
--> fix: re-run with --help to check the invocation grammar, then re-invoke
EXIT=2
```

The machine report it wrote (fresh, this run):

```markdown
# TDD Verification — feature `generators-undeclared-imports`

Generated fresh by `zfa tdd verify --feature generators-undeclared-imports`.

## Gate

- gate: `not_assessed`
- not_assessed_reason: no behavior artifacts registered

## Mutation buckets (FR-014)

- killed: 0
- survived: 0
- timed_out: 0

## Behavior scope (FR-018)

- (no behavior artifacts in scope)

## Restoration (FR-021)

- restoration_verified: true
- restoration_scope_count: 0

## Mutation run

- mutation_was_run: false
```

Machine-generated `zfa tdd verify` output (mutation gates) therefore does
NOT apply to this record: the bug's surface is two generator commands and
a shared core module, not a spec feature with a registered behavior test
list — stated explicitly under "Not proved".

An unrelated preflight hazard was observed and cleared before the
dispatch: the fast-suite `test/plugins/mcp` runs had left three
untracked `.zfa/receipts/mcp-scaffold-scaffold-2026-09-07T*.json` entries
pointing at deleted `/tmp` fixtures (the #1096 cross-suite cwd race),
which made the first dispatch fail receipt preflight with 6 findings.
After deleting the stale receipt files the preflight passed and the run
reached the honest `not_assessed` verdict above.

## Red (before the fix) — ACTUAL

The pin tests (committed in this PR) were run against the pre-fix tree
and failed for exactly the right reasons:

```
dart test test/core/dependencies/pubspec_auto_add_test.dart
→ Error: Undefined name 'PubspecAutoAdd'.          (core module missing)
→ Error: Undefined name 'PubspecGapReporter'.      (core module missing)
→ 00:00 +0 -1: Some tests failed.

dart test test/commands/app_shell_pubspec_deps_test.dart
→ AppShellCommand({FileSystem? fileSystem, AppShellBuilder? builder})
  ^^^^^^^^^^^^^^^   (no processRunner seam, no pubspec handling at all)
→ 00:00 +0 -1: Some tests failed.

dart test test/commands/make_pubspec_auto_add_test.dart
→ (no processRunner seam on MakeCommand)
→ 00:00 +0 -1: Some tests failed.
```

The live behavioral reproduction (in-process `zfa make car
--preset=crud --state --test` against a Flutter-flavored sandbox whose
pubspec did NOT declare `zuraffa`) showed the warn-only defect exactly as
reported in #1265:

```
⚠️  pubspec.yaml doesn't declare 2 package(s) the generated code imports: zuraffa, zuraffa_flutter
    --> fix: `flutter pub add zuraffa zuraffa_flutter`
    note: re-check the whole tree with `zfa doctor`
--- pubspec after ---
(no zuraffa entry — the tree only compiles via a transitive dependency)
```

`zfa app shell` in the same pre-fix tree printed no pubspec diagnostic at
all and left the pubspec untouched — the reported go_router hole.

## Green (after the fix) — ACTUAL

Fix surface (all through the generation pipeline; no hand-edited
generated output):

- `lib/src/core/dependencies/pubspec_auto_add.dart` (new): the shared
  auto-add engine — ONE `<flutter|dart> pub add <packages…>` via an
  injectable process runner (the #1190 doctor `--fix` convention), plus
  `PubspecGapReporter` (the make-consistent `⚠️ doesn't declare … -->
  fix:` wording, now shared).
- `lib/src/commands/make_command.dart`: the #1190 post-pass now auto-adds
  `pubAddPackages`; the ⚠️ diagnostic remains only for what the add
  could not heal (offline/failed adds, SDK-provided packages); JSON mode
  reports `auto_added_pubspec_deps` and remaining `missing_pubspec_deps`.
- `lib/src/commands/app_shell_command.dart`: the shell diffs the package
  imports of the sources it emits against the target pubspec and
  auto-adds the hosted gap (go_router is the headline case);
  `--dry-run` previews the gap without mutation.
- `lib/src/cli/cli_runner.dart`: injectable `makeProcessRunner` seam so
  full-CLI tests stay hermetic.

Focused green run (this session):

```
dart test test/core/dependencies/pubspec_auto_add_test.dart \
          test/commands/app_shell_pubspec_deps_test.dart \
          test/commands/make_pubspec_auto_add_test.dart \
          test/commands/make_pubspec_sync_test.dart
→ 00:14 +20: All tests passed!
```

20/20 — 9 core-engine pins (pub add invocation shape, flutter-vs-dart
selection, no-op, non-zero exit, ProcessException, simulated end state;
diagnostic wording pins), 4 app-shell pins (auto-add go_router via
`flutter pub add`, failure path keeps the ⚠️ + `--> fix:` diagnostic with
no pubspec mutation, dry-run previews without spawning, all-declared
targets spawn nothing), 3 make pins (crud run auto-adds zuraffa and the
rest of the gap, failure path keeps the consistent diagnostic, dry-run
spawns nothing), 4 predecessor #1190 pins updated to the #1265 contract
(M1 auto-add end state, M2 all-declared spawns nothing, M3 json carries
`auto_added_pubspec_deps` and no gap, M4 failed add keeps gap + fix).

Chunked fast-suite runs (no new failures; kernel cache cleaned between
chunks per `tools/run_tests_chunked.sh` convention):

```
dart test test/commands --exclude-tags flutter   → 04:02 +311: All tests passed!
dart test test/core --exclude-tags flutter       → 00:34 +634: All tests passed!
dart test test/plugins/app_shell --exclude-tags flutter
                                                 → 00:01 +83: All tests passed!
```

The two pre-existing #1190 completion tests that pinned the old
warn-only contract (`make_pubspec_sync_test.dart` M1/M3) failed during
the first chunked run BECAUSE the behavior now auto-adds — they were
updated to pin the #1265 contract (M1/M2/M3/M4 above) rather than
left red.

`dart analyze` over the four touched lib files reports only a
pre-existing `prefer_collection_literals` info on `make_command.dart`
(present on master, untouched by this PR).

## Not proved

- The mutation-testing gate (`mutation_was_run: false`) does not apply:
  the engine returned `not_assessed (no behavior artifacts registered)`
  because this bug fixes generator commands, not a spec feature with a
  registered test list. The red→green evidence above is the audit.
- Network-level behavior of the real `pub add` (offline resolution) is
  pinned only at the seam (non-zero exit / `ProcessException` → honest
  diagnostic + no pubspec mutation), not against pub.dev.
