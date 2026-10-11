# Bug Issue: tdd gen still records machine-absolute test_path/subject_path while the run driver records relative — 10 of 18 committed registries are absolute (#1397 corruption is still being written)

- **Slug**: 1574-tdd-gen-relative-paths
- **Fetched**: 2026-09-13T16:55:00-07:00
- **Issue**: 1574
- **URL**: https://github.com/arrrrny/zuraffa/issues/1574
- **State**: open
- **Severity**: unknown (label: `bug`)
- **Author**: arrrrny
- **Labels**: bug

## Body

## Context

Found while verifying #1467 / PR #1543 on `master` at `b621f38b` (zfa v6.2.2, rebuilt). Follow-on to #1397.

#1397 diagnosed this exact corruption — a committed registry mixing machine-absolute and relative records, which makes `zfa tdd gen` refuse with `ownership conflict: the registry test path "test/tdd/..." does not match "/home/z/my-project/zuraffa/..."`, while `zfa tdd doctor` reports *"stores agree — no drift detected"*. That issue was closed by adding *detection* + a `migrate-paths` prescription.

**The corrupting writer was never fixed, and the drifted data was never migrated.** New absolute records are still being written today.

## Evidence — the writer still composes absolute paths

`lib/src/plugins/tdd/commands/gen_command.dart:290-292` — both branches of `cwd` yield an absolute path:
```dart
final cwd = projectFlag != null && projectFlag.isNotEmpty
    ? p.absolute(projectFlag)
    : ProjectRoot.find(anchorDir: 'specs');
```

`lib/src/plugins/tdd/commands/gen_command.dart:937-938` — composed straight from that absolute `cwd`:
```dart
final testPath = '$cwd/test/tdd/$featureName/${snakeId}_test.dart';
final subjectPath = '$cwd/lib/tdd/$featureName/${snakeId}_subject.dart';
```

`run_driver_core.dart` was later normalized to the relative form (`lib/src/plugins/tdd/commands/run_driver_core.dart:2304-2306`, commit `af40f686b`, 2026-09-08), but `gen_command.dart` was not:

```dart
final relativeTestPath = testPath != null
    ? p.relative(testPath, from: projectRoot)
    : p.join('test', 'tdd', feature, '${_snakeCase(behaviorId)}_test.dart');
```

So the two writers disagree by construction — which is precisely the mixed-path-form registry that #1397 described.

## Evidence — the drift is live, not historical

A census of every tracked `artifacts.json` at `master`, classifying the first record's `test_path`:

| Recorded form | Registries |
|---|---|
| absolute | **10** |
| relative | 7 |
| empty | 1 |

Absolute is the *majority* form, not an edge case.

Concrete instance — `.specify/bugs/cycle-log-phantom-sections/tdd/artifacts.json` (written by `zfa tdd gen` on 2026-09-10, weeks after #1397 closed):

```json
{"behavior_id":"A1","test_path":"/Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a1_test.dart",
 "subject_path":"/Users/arrrrny/Developer/zuraffa/lib/tdd/cycle-log-phantom-sections/a1_subject.dart",
 "runnable_test_name":"/Users/arrrrny/Developer/zuraffa/test/tdd/cycle-log-phantom-sections/a1_test.dart::A1::the in-fence `## ` lines do NOT start", ...}
```

All five behaviors A1–A5 carry the same absolute prefix. `runnable_test_name` embeds it a third time, so a single drifted record has three absolute fields.

`zfa tdd doctor` flags all of it:

```
$ zfa tdd doctor .specify/bugs/cycle-log-phantom-sections
  drift: A1: the recorded test path is machine-absolute ... — records must be project-relative to stay portable
  ... (10 drift lines)
```

## Why this matters

- These paths only resolve on a clone at the identical absolute path. Any other checkout, CI runner, or container gets #1397's refusal.
- The failure is silent at the point of damage (`gen` writes it happily) and appears much later as an `ownership conflict` at the next `gen` — the diagnostic gap #1397 was filed about.
- The prescribed remedy cannot clear it: `zfa tdd migrate-paths --feature <name>` only reads `specs/<feature>/tdd/artifacts.json` (`migrate_paths_command.dart:873,876-878`), never `.specify/bugs/`. Filed separately with full repro.

## Proposed fix

1. Normalize at the writer: compose `test_path` / `subject_path` with `p.relative(..., from: cwd)` in `gen_command.dart:937-938`, and build `runnable_test_name` from that relative form. This is the change that stops new drift.
2. Migrate the existing drifted registries once the remedy actually reaches them. Note the 10 absolute registries are not all defects — several are deliberate fixtures with synthetic prefixes (`corpus/regression/make-baseline-cache/...`, `examples/todo_tdd/...`, `/tmp/...`), so a blanket rewrite would corrupt fixtures. Each needs a look before rewriting.
3. Add a guard test that fails on a *non-fixture* registry whose record starts with `/`, so this cannot silently return.

## Note

Item 2 is why this is filed separately from the remedy bug rather than as one "just run migrate-paths" ticket — the cleanup is blocked on the remedy, and the remedy's scope also needs extending before either can be closed.

## Comments

None.
