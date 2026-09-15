**Template Version**: `zuraffa-1.0`

# Plan: 1637-build-skip-content-hashing

## Technical Context

- Language/Dart SDK: ^3.11.0 (repo pin), running on Dart 3.13.4 stable
  (this checkout). Pure-Dart root package; no Flutter SDK required.
- CLI surfaces involved:
  - `lib/src/plugins/tdd/services/build_relevance.dart` — the ONLY
    production file modified. `BuildRelevance.refactorBuildSkipNote`
    (issue #1624 gate, L~245) is the refactor build pass's scheduler:
    it walks `lib/ test/ bin/ tool/` plus `buildConfigFiles`, keeps
    every file whose mtime is NOT before the
    `.dart_tool/build/asset_graph.json` marker, and returns the skip
    note when none of the newer files can feed a builder. Step 4 of
    its doc'd contract ("any newer config file → run") is the #1637
    defect: a byte-identical config refresh has a fresh mtime and
    forces the pass.
  - `BuildRelevance.fingerprint` (L~148) + `_digestOf` (L~308) — the
    existing content-hash mechanism (FNV-1a 64-bit, zero-padded hex)
    the config tier now reuses; `fingerprint` already hashes every
    `buildConfigFiles` entry with `_digestOf`, so the fallback digest
    and the baseline digest are the same function of the same bytes.
  - `BuildRelevance.canSkipTerminalBuild` (L~169) — the make's
    terminal-build gate. ALREADY content-based (a byte-identical
    refresh hashes equal and `continue`s past the config rule), so it
    never had this bug. NOT modified (hard constraint).
  - `lib/src/plugins/tdd/services/refactor_passes.dart` — the pass
    registry; `defaultPassSpecs` binds `refactorBuildSkipNote` as the
    build spec's `skipGate` (L~357). A non-null note records a
    synthetic skipped action and never spawns the pass; the binding
    seam is untouched — the fix lives entirely inside the gate.
  - `lib/src/commands/build_command.dart` — the `zfa build` child and
    the asset-graph writer (build_runner). NOT modified (hard
    constraint).
- Test surfaces (existing, reused):
  - `test/plugins/tdd/services/build_relevance_test.dart` — the
    `refactorBuildSkipNote (issue #1624)` group builds the gate's
    fixture idiom: temp project root, backdated marker
    (`setLastModifiedSync(now - 1h)`), natural mtimes for "newer"
    files, backdated writes for "older" ones. The #1637 group extends
    this idiom with a two-phase marker bump that stands in for a
    completed build.
  - `test/plugins/tdd/services/refactor_passes_test.dart` — binds the
    REAL gate to a scratch project (issue #1624 test) and asserts its
    verdicts; untouched, doubles as the no-drift regression guard.
- zfa-owned state under `.dart_tool/` is established repo practice
  (`kZfaBinaryCacheDir = ['.dart_tool', 'zfa_cli_bin']` in
  `lib/src/cli/zfa_executable.dart`, `.dart_tool/zfa_tdd_cycle.pid` in
  `kernel_cache.dart`); the gate-owned baseline follows it.

## Design

### 1. Gate-owned config baseline

`build_relevance.dart` gains a private baseline record stored at
`.dart_tool/zfa/build_config_baseline.json` (relative, POSIX):

```json
{
  "version": 1,
  "markerMtimeMillis": 1730000000000,
  "digests": {
    "pubspec.yaml": "0cbf29ce48422232",
    "pubspec.lock": "…",
    ".dart_tool/package_config.json": "…"
  }
}
```

- `digests` is a `configFingerprint(projectRoot)` snapshot — every
  existing `buildConfigFiles` entry hashed with the existing
  `_digestOf` (FR-003: the fingerprint mechanism, not a new hash).
- `markerMtimeMillis` is the asset-graph marker's mtime observed when
  the baseline was written. Validity rule (FR-004): the CURRENT
  marker's mtime must be STRICTLY newer. The gate writes the baseline
  only on a run decision, and the build pass that follows (when it
  completes) moves the marker — so a trusted baseline means "a
  completed build consumed exactly these digests". A failed or
  never-spawned build leaves the marker untouched, the strictness
  fails, and the baseline stays untrusted (AC-4, fail-safe).

### 2. The config tier of `refactorBuildSkipNote`

New step 4 (replacing "any newer config file → run"):

1. Partition the newer set: config files (`buildConfigFiles.contains`)
   vs. the rest.
2. If there are newer config files:
   a. Load + validate the baseline (missing / corrupt / wrong version
      / not-strictly-older marker mtime → untrusted; every read error
      → untrusted; never throws).
   b. Trusted → hash the newer config files' current bytes with
      `_digestOf` (via `configFingerprint`, the fingerprint
      mechanism). ALL match the baseline → the config tier is CLEARED
      (byte-identical refresh — the reported regression). Any mismatch
       → run (FR-001/FR-005).
   c. Untrusted → run (fail-safe, identical to #1624), and record a
      fresh baseline (current digests + current marker mtime) so the
      next completed build validates it (FR-006).
3. The non-config newer files then decide exactly as before (non-Dart
   → run; annotated `.dart` → run; otherwise skip) — AC-6 shapes are
   untouched.
4. Recording (when it happens) is best-effort: the directory is
   created if needed, write errors are swallowed, and the skip path
   NEVER rewrites the baseline (rewriting with the current marker
   mtime would self-invalidate the record until the next build).

### 3. What deliberately does NOT change

- The mtime pre-filter walk (step 2 of the #1624 contract) — byte for
  byte (FR-002).
- The skip note constant's role: `refactorBuildSkippedNote` stays THE
  skip evidence; its text gains the #1637 clause so the recorded
  evidence states the config-hash clearing honestly instead of
  over-claiming "un-annotated plain Dart".
- `canSkipTerminalBuild`, `shouldSkipTerminalBuild`, `fingerprint`,
  the make path, the pass registry, the build command, build_runner.

### 4. Failure-mode table

| condition | verdict | why |
| --- | --- | --- |
| marker missing | run | never been built here (#1624 rule 1) |
| no newer file | skip | nothing to consume (#1624 rule 3) |
| newer config, no baseline | run + record | fail toward RUN (AC-3) |
| newer config, corrupt baseline | run + record | parse/IO error never fabricates a skip |
| newer config, baseline not strictly older than marker | run + record | no completed build since recording (AC-4) |
| newer config, trusted baseline, digest match | clear tier | byte-identical refresh (AC-1; AC-5 for dart_test.yaml / analysis_options.yaml) |
| newer config, trusted baseline, digest mismatch | run + record | real config change (AC-2; AC-5 for dart_test.yaml / analysis_options.yaml) |
| newer non-Dart / annotated .dart | run | unchanged (#1624 rule 4) |
| all newer files cleared (plain dart + cleared configs) | skip | the #1637 win |
| any filesystem/decode error anywhere | run | catch-all unchanged |

## Risks / Trade-offs

- The baseline is mutable state in `.dart_tool/zfa/` — loss or tearing
  degrades to one extra build run (fail-safe), never a wrong skip;
  `.dart_tool` is already ephemeral (regenerated by pub/build_runner).
- Two gate calls racing on the same project would both write the
  baseline last-wins — the refactor registry is sequential per
  project, and a torn write parses as corrupt → run (fail-safe).
- FNV-1a is not cryptographic; the threat model is the CLI's own
  writes, not adversarial collisions — inherited unchanged from the
  #1587 fingerprint decision.
