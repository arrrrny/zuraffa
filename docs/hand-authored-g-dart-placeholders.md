# Hand-authored `.g.dart` placeholders — protecting tracked part files from build cleanup

> Spec 1540 (`specs/1540-protect-git-tracked-g-dart-from-build/`). Applies to
> `zfa build` and `zfa tdd refactor` on the zuraffa CLI (6.x+).

## The pattern

A **hand-authored placeholder** is a generated-name file — `*.g.dart` or
`*.zorphy.dart` — that a human writes and git tracks, but that **no generator
produces**. The classic case (issue #1540):

```dart
// lib/src/engine/events/engine_event.dart
part 'engine_event.g.dart';

sealed class EngineEvent { /* ... */ }
```

…with `engine_event.g.dart` maintained by hand. The source declares the part
(and the package compiles only because the file exists), yet no builder owns
that output: the class is intentionally not annotated, or the code inside is
deliberately manual.

## Why the build deletes it

json_serializable's builder **reserves `<lib>.g.dart` as the output for every
library in `generate_for`** (the scaffolded/default `build.yaml` covers
`lib/src/**` and `test/**`). When build_runner runs:

1. Every library in `generate_for` gets an expected output path
   `<lib>.g.dart`.
2. A pre-existing `.g.dart` whose producing generator did **not** run in this
   build is classified as a stale/orphaned output.
3. build_runner's cleanup **deletes** it. By filename convention a
   hand-authored placeholder is indistinguishable from an orphaned output.

Because `engine_event.dart` declares `part 'engine_event.g.dart';`, the
deletion leaves a broken package. `zfa build`'s completeness gate
(`verifyDeclaredPartsOrFail`) then fails, the command exits non-zero, and a
`zfa tdd refactor` pass misfire-stops — the loop dead-ends with the tree
broken and (before spec 1540) no remedy named.

## What zfa does now (spec 1540)

- **`zfa build`** snapshots every generated-name file that is tracked in
  git's index and present on disk **before** build_runner runs, and restores
  the exact pre-build bytes of anything the build deletes — reporting what it
  restored and the pattern remedy. Unstaged hand edits survive (the snapshot
  bytes are restored, not the git index content).
- **Restore-or-refuse**: if a deletion cannot be restored (e.g. the build
  removed the whole directory), `zfa build` — and the `zfa tdd refactor`
  build pass — **refuse** with the exact manual remedy instead of
  reporting success on a broken tree.
- **Completeness gate**: when a declared part is missing and git shows the
  path as tracked, the gate's failure message names the deletion and prints
  the restore command below.
- Non-git projects (and untracked files) are untouched: only tracked ∧
  present-before / absent-after files are acted on, so legitimate `.g.dart`
  regeneration is never blocked or reverted.

Manual restore:

```bash
git checkout -- lib/src/engine/events/engine_event.g.dart
```

## Stopping the recurring deletion: `build.yaml` exclusions

Without exclusions, every build deletes the placeholder again (zfa restores
it again — functional, but noisy). Exclude the **owning library** (the file
declaring the part) from BOTH builders that would claim its output:

```yaml
# build.yaml
targets:
  $default:
    builders:
      json_serializable:
        generate_for:
          exclude:
            - lib/src/engine/events/engine_event.dart
      source_gen:combining_builder:
        generate_for:
          exclude:
            - lib/src/engine/events/engine_event.dart
```

`source_gen:combining_builder` matters as much as `json_serializable`: it
assembles `part of` files and treats the missing output the same way. If you
use additional builders that emit `<lib>.g.dart` parts for the library,
exclude the library from each of them.

If your `generate_for` uses include-lists instead of `exclude:` — or nested
`targets:` keys — add the same `exclude` entry under the builders that
already select `lib/src/**`.

## Rewrites: a failed build must not keep half-applied rewrites (issue #1953)

A builder can also REWRITE a tracked placeholder instead of deleting it —
the reported case: `hive_ce_generator`'s registrar flow clobbered a
hand-curated `lib/src/cache/hive_registrar.dart` (its curated
`hide DeviceInfo` import lost), and the build then failed at
`source_gen:combining_builder` — leaving the broken, rewritten file on disk.

`zfa build` covers this too: the snapshot/restore guard tracks
`hive_registrar.dart` by basename (a generated-name output with no
generated suffix), and on a FAILED build it restores the exact pre-build
bytes of every tracked generated-name file the build rewrote — a failed
build must not keep half-applied rewrites. On a successful build a rewrite
is a generator legitimately producing its output and is never touched.

The failure output names the exact exclusion that stops the clobber
recurring — for a suffix-less placeholder, the file itself:

```yaml
source_gen:combining_builder:
  generate_for:
    exclude: [lib/src/cache/hive_registrar.dart]
```

(and every other builder that emits the output — e.g.
`hive_ce_generator:hive_registrar_generator` for Hive registrar files).
For suffixed outputs (`.g.dart`), exclude the owning library, exactly as
for deletions.

## Legitimizing a placeholder instead

Exclusions freeze the placeholder as hand-written code. Two alternatives when
that is not what you want:

1. **Give the file a real owner**: annotate the classes in the owning
   library (`@Zorphy`, `@JsonSerializable`-reachable via zorphy) so a
   generator genuinely produces `engine_event.g.dart` — then the placeholder
   content moves into the generator's domain and regeneration is legitimate.
2. **Untrack the placeholder**: if the file is really scratch output, remove
   it from the index (`git rm --cached lib/src/engine/events/engine_event.g.dart`).
   The spec-1540 guard protects only git-tracked files — an untracked file
   is treated as disposable.

## Quick reference

| Symptom | Meaning | Fix |
| --- | --- | --- |
| `♻️ Restored … (spec 1540)` on every build | placeholder tracked, not excluded | add both `build.yaml` excludes (above) |
| `♻️ Restored … REWRITTEN … (issue #1953)` | a builder rewrote a tracked placeholder during a FAILED build (bytes auto-restored) | add the `generate_for.exclude` named in the failure output |
| `❌ … could not restore … (spec 1540)` | deletion cannot be undone by zfa | `git checkout -- <path>`, inspect what removed the directory |
| gate message with `git checkout -- <path>` | declared part missing ∧ git-tracked | restore, then add the excludes |
| `refactor … refused … [1540]` | refactor build pass hit an unrestorable deletion | restore via git, re-run `zfa tdd refactor` |
