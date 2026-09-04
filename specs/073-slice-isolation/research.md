# Research: Slice-Driven Isolation (073)

## R1 — What the slice plugin already has

- Capabilities: `cut_slice_capability.dart` (`cut_slice`),
  `export_slice_capability.dart` (`export_slice`),
  `merge_slice_capability.dart`, `verify_slice_capability.dart`
  (`verify_slice`) — all `ZuraffaCapability` implementations behind
  `slice_command.dart`.
- Models: `slice_manifest.dart` (the declared facts), `slice_boundary`,
  `slice_depth`, `slice_file`, `file_graph`.
- Verifier: `import_verifier.dart` + `analyze_runner.dart` (import-scan
  and analyze exist — self-containment extends these).
- Merger: `slice_merger.dart` + `conflict_detector.dart`.

**Gap analysis (what the issue names missing)**: cut does not emit a
RUNNABLE sandbox (no shell/router/DI composition), verify has no
machine-readable self-containment+mock-certification+suite verdict, and
nothing ties the tdd loop's project root to the sandbox or carries the
journal/registry through merge.

## R2 — Runnable sandbox composition

**Decision**: `cut` composes four deterministic generators:
1. spec + tdd artifacts copy (existing exporter),
2. minimal app shell (reuse the `app_shell` plugin's proven skeleton
   output — ShadApp/MaterialApp per target profile),
3. router harness exposing exactly the manifest's declared routes
   (generated `routes()` returning the feature's route table),
4. DI bootstrap binding certified mocks for every declared dependency:
   072's `zfa mock dependency` artifacts for service/storage rows, the
   channel fake rail (`zfa tdd fake`) for channel rows — both imported
   into the sandbox's pubspec path/runtime config.

Determinism: pure templates, manifest-keyed output, no timestamps.

## R3 — Self-containment scan

`import_verifier` scans imports; extend with a **host-reference scan**:
any import/path/asset reference that resolves OUTSIDE the sandbox root
(and outside the Dart SDK / declared sandbox deps) fails
self-containment, each offender named. **Decision**: substring of the
host root path is the naive check; the robust check resolves relative
URIs against the sandbox file and flags anything escaping the root.

## R4 — Verify verdict

**Decision**: `verify_slice --json` emits
`{"selfContainment": {...}, "mockCertification": {...}, "suiteState": {...}}`
with per-check pass/fail + offender lists; exit 0 iff all pass. Suite
state runs the sandbox suite via the profile's file/suite commands
(tdd-profile) inside the sandbox root. Merge reads the same verdict —
absent or failing verdict refuses merge (FR-005).

## R5 — The loop in the sandbox

The tdd commands accept `--project` (sandbox root). **Decision**: the
slice runner writes a sandbox-local `.specify/memory` copy of the
profile (the loop needs the profile at the project root) and the
journal/registry paths resolve inside the sandbox — receipts travel
with the slice. No new loop flags.

## R6 — Merge landing + host suite

`merge_slice` lands artifacts + journal + registry into the host
(existing merger), then runs the HOST suite (baseline-aware per
#741/#953: pre-existing reds tolerated, new reds reported — full
conformance gating is 074). **Decision**: merge prints the host-suite
outcome line and refuses when verify is failing/absent.

## R7 — Alternatives rejected

- **Symlinked sandbox** (mount host packages): rejected — defeats
  self-containment verification.
- **Hand-authored sandbox template repo**: rejected — determinism and
  manifest-keyed generation are the plugin's job; a template drifts.
- **New orchestration CLI outside the plugin**: rejected — the
  capabilities exist; completion beats invention (issue: "proving +
  completion pass, not new invention").
