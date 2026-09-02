# Assessment: tdd-gen-project-autodetect-890

## Severity: high (workflow-blocking)

Every TDD command resolves the project root from CWD when `--project` is
absent. A wrong resolution is not an edge case for TDD: the loop's core
promise is `zfa tdd plan → run → verify` driven from the project root.
When the resolution silently picks an ancestor, every U*:gen step dies with
`unknown behavior id` and the operator has no signal that the ROOT was
wrong — the message reads like a missing test-list row.

## Root cause (verified on master bd535c07)

`ProjectRoot.find()` (lib/src/core/project/project_root.dart) anchors ONLY
on `pubspec.yaml`: it walks up from CWD and returns the nearest ancestor
carrying one.

The TDD commands' true project root is the directory holding `specs/`
(`specs/<feature>/tdd/test-list.md`, `test/tdd/`, `lib/tdd/`, the artifact
registry). When the TDD root has no `pubspec.yaml` of its own while an
ancestor does (any parent workspace/IDE folder — exactly the reported
forklift layout), the walk returns the ANCESTOR:

- `zfa tdd gen U24 --feature 004-...` scans `<ancestor>/specs` → missing →
  `unknown behavior id "U24"` (the issue's byte-for-byte output was
  reproduced from a fixture)
- `zfa tdd run <feature>` mis-resolves the same way and dies before or at
  the gen step (`no feature directory at specs/...` / `[run] U24 gen ->
  error`)
- `--project <root>` pins the root and works — matching the report

What was NOT the problem (verified before fixing):

- The run driver DOES always pass `--project <root>` to every spawned step
  (`StepRunner.run`, since #608) — the second remediation the issue offers
  is already implemented. The driver failed because its own top-level
  `ProjectRoot.find()` resolved the wrong root and handed that root to the
  spawn.
- Normal layouts (pubspec.yaml + specs/ at the same root) resolve correctly
  on master, both directly and through the driver.

## Remediation

1. `ProjectRoot.find({String? startPath, String? anchorDir})` — the walk
   stops at the first ancestor containing `pubspec.yaml` OR a direct child
   directory named `anchorDir`; the nearest project marker wins. Callers
   that pass no anchor keep the exact legacy pubspec-only semantics (all
   non-TDD callers are untouched).
2. All 17 TDD-plugin command call sites pass `anchorDir: 'specs'`
   (gen, run, plan, verify-red, make, refactor, verify, func, wire,
   compose, init, reset, doctor, migrate-paths, corpus run/status/audit) —
   the same wrong-root failure class applies to every one of them.
3. gen diagnosability: when the resolved root has no `specs/` directory at
   all, the unknown-behavior error now names the scanned root and suggests
   `--project`, so a mis-resolution is visible on the spot instead of
   looking like a missing row.
4. `zfa tdd run` needs no code change: its top-level resolution is fixed by
   (1), and it already hands `--project <root>` + `workingDirectory` to
   every spawned step.

## Risk

Low. The anchor only ADDS a stop condition to the walk for TDD callers:
- pubspec + specs at the same root (the overwhelmingly common layout):
  resolution identical to before
- pubspec nearer than specs: pubspec still wins at its own level
- no specs anywhere: walk unchanged
Non-TDD callers (entity/make/build/plugin system) keep the pubspec-only
walk because they do not pass an anchor.
