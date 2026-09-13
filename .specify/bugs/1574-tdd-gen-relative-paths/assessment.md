# Bug Assessment: tdd gen still records machine-absolute test_path/subject_path while the run driver records relative

- **Slug**: 1574-tdd-gen-relative-paths
- **Created**: 2026-09-13T17:05:00-07:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/1574
- **Verdict**: valid — reproduced empirically on a scratch project (both lanes)
- **Severity**: unknown (label: `bug`)

## Report (verbatim or summarized)

Follow-on to #1397. The #1397 fix added *detection* (doctor path-form drift) + a
`migrate-paths` prescription and canonicalized the registry's persisted form —
but the corrupting writer (`gen_command.dart`) was never normalized, and the
drifted committed data was never migrated. The issue's census at `master`: of 18
tracked `artifacts.json` registries, 10 record machine-absolute
`test_path`/`subject_path`, 7 record the relative form, 1 is empty. Absolute is
the majority form.

## Symptom

`zfa tdd gen` records machine-absolute `test_path`/`subject_path`
(`/home/.../zuraffa/test/tdd/...`) in the registry and in its verdict output,
while `run_driver_core.dart` records the relative form (`test/tdd/...`,
commit `af40f686b`). The two writers disagree by construction; committed
absolute records resolve only on a clone at the identical absolute path and
surface later as `ownership conflict` refusals (the #1397 diagnostic gap).

## Reproduction

Reproduced on a scratch project at `master` (this branch, pre-fix), driving
`CliRunner` with `tdd gen --project <tmp> --feature <ref> A1`:

- specs lane (`specs/010-demo-feature`): the persisted registry record is
  relative (`test/tdd/...`) — the #1397 `_canonicalize` write-path net holds —
  but gen's emitted record/verdict still carries the absolute form
  (`test_path: /tmp/.../test/tdd/...`).
- bug lane (`.specify/bugs/010-demo-bugfix`): the persisted registry record is
  **machine-absolute** — the corruption is live today. This matches the
  committed `.specify/bugs/cycle-log-phantom-sections/tdd/artifacts.json`
  (`/Users/arrrrny/Developer/zuraffa/test/tdd/...`, written 2026-09-10).

## Suspected Code Paths

- `lib/src/plugins/tdd/commands/gen_command.dart:312-314` — `cwd` is always
  absolute (`p.absolute(projectFlag)` or `ProjectRoot.find`).
- `lib/src/plugins/tdd/commands/gen_command.dart:966-967` — `testPath`/
  `subjectPath` composed straight from that absolute `cwd`.
- `lib/src/plugins/tdd/commands/gen_command.dart:977` — `runnableTestName`
  embeds the absolute `testPath` as its first `::` segment.
- `lib/src/plugins/tdd/commands/gen_command.dart:1045-1056` — the
  `ArtifactRecord` is built from the absolute forms.
- `lib/src/plugins/tdd/services/artifact_registry.dart:463-473` —
  `ArtifactRegistry.projectRoot` only recognizes a `specs/`-parented feature
  directory; for the bug extension's documented `.specify/bugs/<slug>` shape
  (issue #1182) it resolves the project root to `<root>/.specify/bugs`, so
  `_canonicalize` cannot relativize the absolute record and the absolute form
  survives the write (the live leak).
- `lib/src/plugins/tdd/commands/run_driver_core.dart:2655-2657` — the run
  driver's already-normalized relative form (the reference shape; NOT to be
  changed).

## Root Cause Hypothesis

`gen_command.dart` composes the record's artifact paths from the
machine-absolute `cwd` and never derives the project-relative form, while
`run_driver_core.dart` was normalized to the relative form (commit `af40f686b`).
In the specs lane the registry's `_canonicalize` masks this on persist; in the
`.specify/bugs/<slug>` lane the registry's project-root heuristic cannot
resolve the lanes against the mis-derived root, so the absolute form survives
the write. Result: two writers disagreeing by construction, and 10 of 18
committed registries in the drifted (absolute) form.

## Proposed Remediation

1. **Writer (gen_command.dart)** — compose the RECORD paths in the portable
   project-relative POSIX form: `p.relative(testPath, from: cwd)` /
   `p.relative(subjectPath, from: cwd)`, and build `runnableTestName` from the
   relative form — exactly the shape the issue requests and `run_driver_core.dart`
   already records. The absolute `testPath`/`subjectPath` locals stay for all
   on-disk I/O (writers, preflight stat, i18n import anchoring); only the record
   form changes.
2. **Registry resolution (artifact_registry.dart, minimal & disclosed)** —
   teach `ArtifactRegistry.projectRoot` the documented `.specify/bugs/<slug>`
   shape (issue #1182) so relative records locate, compare, and canonicalize
   against the real project root in the bug lane. Without this, a relative
   record in the bug lane resolves against `<root>/.specify/bugs` and the
   ownership gate reports owned-but-missing for files that exist — i.e. the
   writer fix alone would trade the persist leak for a reuse refusal
   (StateError / ownedButMissing). Gate semantics are unchanged: absolute
   records resolve exactly as before; only relative-record resolution moves
   from a nonexistent location to the real files.
3. **Data migration** — rewrite the 10 committed absolute-path registries to
   the relative form (strip the stale machine prefix at the last `/test/` or
   `/lib/` marker, mirroring `reanchorRecordPath`'s semantics; rebuild
   `runnable_test_name`'s first segment). Verified before rewriting: no test
   asserts any fixture's absolute forms (the corpus entries are driven by
   `entry.json`, not `artifacts.json` path forms), and doctor's own drift rule
   defines the relative form as the canonical healthy form.
4. **Guard tests** — a red/green suite (`bug_1574_gen_relative_paths_test.dart`)
   asserting: fresh gen persists relative records in BOTH lanes; gen's emitted
   record/verdict carries the relative form; re-gen against a relative
   (run-driver-written) registry reuses without ownership conflict in the bug
   lane.

## Risks & Considerations

- The issue's hard constraint says "Fix ONLY the path composition in
  gen_command.dart + migration". Remediation item 2 touches
  `artifact_registry.dart` — it is disclosed here and in the PR because the
  writer fix alone provably breaks bug-lane reuse (the registry locates
  relative records against `<root>/.specify/bugs`). The change is pure
  path-resolution: no gate rule, no verify semantics, no closure scan, no
  run_driver_core.dart change.
- Migration of the two fixture-style registries (`corpus/regression/...`,
  `examples/todo_tdd/...`) is deliberate: the issue flags "blanket rewrite
  would corrupt fixtures", but the census + test-sweep shows nothing consumes
  their absolute forms, while the canonical contract (and doctor) define the
  relative form as the only portable/healthy one.
- `zfa tdd migrate-paths` cannot perform the migration itself: it only reads
  `specs/<feature>/tdd/artifacts.json` (migrate_paths_command.dart:873,876-878),
  never `.specify/bugs/` — so the committed registries are rewritten directly
  (JSON-only, no file moves), mirroring the tool's own form rewrite.

## Open Questions

- None blocking: the issue's acceptance criteria are explicit and the
  reproduction is empirical.
