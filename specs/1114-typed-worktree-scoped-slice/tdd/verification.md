# TDD Verification — feature `1114-typed-worktree-scoped-slice`

Deterministic engine result from `zfa tdd verify --feature
1114-typed-worktree-scoped-slice` (receipt preflight + mutation audit),
followed by the real gate evidence for this spec's red → green cycle.
Every number below is from an actual run on this branch — nothing is
projected.

## Gate

- gate: `not_assessed` — the engine's automated mutation bucket is empty
  (this is a CLI/tooling spec: no behavior artifacts are registered for
  mutation, exactly like the landed spec 1138; the mutation audit below
  supplies real manual mutants instead)
- receipt preflight: `receipt preflight: skipped (no receipts shipped —
  proof-carrying generation not in use)` (one stale test-run receipt
  under `.zfa/receipts/` from the fast-suite mcp chunk pointed at a
  deleted `/tmp/zfa_plugin_mcp_test_*` fixture — removed as
  housekeeping, the same class of stray the 1138 run removed)
- engine mutation buckets: killed 0 / survived 0 / timed_out 0
  (`mutation_was_run: false` — no behavior artifacts registered)
- restoration_verified: true (all three manual mutants reverted byte-exact
  (`cmp` against pre-mutation backups); post-restoration reruns of the
  spec-1114 suites all green)

## Gates (the spec's VERIFY section, actually run)

### 1. `dart analyze`

**134 issues — exactly the master baseline (134).** Pre-existing
31 error/warning lines are all in `examples/todo_tdd` (missing generated
imports, present on clean master before any of this branch's edits —
proven by `git stash -u` → `dart analyze` → 134 issues → `git stash
pop`). Zero new issues from this branch's 11 new files + 4 modified
files.

### 2. `tools/run_tests_chunked.sh` (fast suite, chunked)

**90 chunks — 84 passed, 6 skipped, 0 failed.** The 6 skips are the
all-slow-tagged folders the fast tier excludes by design
(`test/benchmark`, `test/core/dependencies`, `test/core/proof`,
`test/integration`, `test/plugins/tdd/scenarios`,
`test/tdd/077-make-engine-preset` — each prints `No tests ran` +
`SKIP: no fast-tier tests in <d>`, the runner's sanctioned skip path).
The run was executed chunk-by-chunk with kernel-cache cleanup (the
runner's own `clean_kernel`); after the final edits, every affected
chunk was re-run green: `test/plugins/slice` (+132), `test/commands`
(+246), `test/core/plugin_system` (+37), `test/plugins/feature` (+6),
`test/plugins/skin_contract` (+30), `test/domain` (+43), `test/skin`
(+82).

### 3. `dart format .`

**Idempotent.** First run: `Formatted 2361 files (16 changed)` — 13
files of this change set plus 3 pre-existing drifted files under
`examples/todo_tdd/test/tdd/` (master drift; picked up because the gate
mandates `dart format .` over the whole tree). Second run:
`Formatted 2361 files (0 changed)`, and
`dart format --output=none --set-exit-if-changed .` exits 0.

### 4. `git diff --stat`

18 files changed (7 modified, 11 added): the plugin_context extension,
the typed resolution service, the feature-centric manifest, the slice
composer, the worktree + check capabilities, the compose capability
extension, the slice command wiring, the xray shared-resolution, and
the 6 new test files (+ shared fixture). Zero remaining formatting
diffs (gate 3 proves idempotence).

## TDD cycle (red → green)

### Red evidence (before any implementation)

All 6 new spec-1114 test files failed to LOAD against the unmodified
codebase (the APIs did not exist — the raw-string compose, the
entity-centric manifest, no worktree, no check, no context contract):

```
00:00 +0 -6: Some tests failed.
  test/plugins/slice/models/feature_slice_manifest_test.dart: loading …
  test/plugins/slice/capabilities/compose_feature_slice_test.dart: loading …
  test/plugins/slice/capabilities/slice_worktree_capability_test.dart: loading …
  test/plugins/slice/capabilities/slice_check_capability_test.dart: loading …
  test/plugins/slice/slice_command_worktree_check_test.dart: loading …
  test/core/plugin_system/plugin_context_feature_contract_test.dart:
    Error: The getter 'activeFeatureContract' isn't defined for the type
    'PluginContext'. … (+ the missing FeatureSliceManifest /
    SliceWorktreeCapability / SliceCheckCapability /
    resolveFeatureContract / slice worktree|check subcommand errors)
```

### Green evidence (after the implementation)

| Suite (file) | Result |
| --- | --- |
| `test/plugins/slice/models/feature_slice_manifest_test.dart` (new) | **6/6 passed** |
| `test/plugins/slice/capabilities/compose_feature_slice_test.dart` (new) | **13/13 passed** |
| `test/plugins/slice/capabilities/slice_worktree_capability_test.dart` (new) | **6/6 passed** |
| `test/plugins/slice/capabilities/slice_check_capability_test.dart` (new) | **6/6 passed** |
| `test/plugins/slice/slice_command_worktree_check_test.dart` (new) | **8/8 passed** |
| `test/core/plugin_system/plugin_context_feature_contract_test.dart` (new) | **2/2 passed** |
| **New spec-1114 tests total** | **41/41 passed** |
| `test/plugins/slice/capabilities/compose_slice_capability_test.dart` (pre-existing, spec 1098) | **7/7 passed** (unbroken) |
| `dart test test/plugins/slice --exclude-tags flutter` (whole folder) | **+132: All tests passed** |

## Mutation audit (real mutants, real kills)

Each mutant applied to the branch's code, compiled, tested against the
spec-1114 suites, then restored byte-exact (`cmp` identical after
restore; post-restoration rerun green).

| Mutant | Mutation | Result |
| --- | --- | --- |
| M1 | `slice_check_capability.dart`: `_expandLayers(XRayLayer.presentation)` → `{'presentation'}` only (drop the transitive expansion) | **KILLED** — 2 tests failed in `slice_check_capability_test.dart` ("a composed slice checks green" and "an agent EDIT inside the slice is allowed"): the domain/data engine files of a presentation-layer contract get wrongly reported as layer violations |
| M2 | `feature_slice_composer.dart`: routes-by-specificity sort reversed (prefix route claims multi-segment views first) | First run: **SURVIVED** — no test pinned per-view route attribution. The audit did its job: the test was WEAK. Strengthened `compose_feature_slice_test.dart` ("slice.yaml is feature-centric") with the specific-route attribution assertions (`login_forgot_view.dart` → `/login/forgot`, `skinRoutes[/login/forgot].view == 'LoginForgotView'`), re-applied the mutant → **KILLED** (`+12 -1: Some tests failed`). The strengthened assertions ship with the branch |
| M3 | `slice_worktree_capability.dart`: `--show-toplevel` check → `--is-inside-work-tree` (the subdirectory bug this branch fixed) | **KILLED** — `slice_worktree_capability_test.dart` "records the parent linkage for the glue-back" fails: the parent repo is hijacked onto branch `slice/login` (parent_branch ≠ master) |

Survivors: 0 (after the M2 test strengthening). Timed out: 0. Post-restoration reruns: all suites green.

## Success criteria — PROVED vs NOT

| Criterion (issue #1114) | Status | Evidence |
| --- | --- | --- |
| `zfa slice compose <id>` writes engine/ + skin/ + contract/ + receipts/ | **PROVED** (fast suite) | `compose_feature_slice_test.dart` "writes .zfa/slices/login/ with engine/ skin/ contract/ receipts/" + `slice_command_worktree_check_test.dart` dispatch |
| The slice's engine/ has only the contract's entities; skin/ only the contract's routes | **PROVED** (fast suite) | "engine/ has ONLY the contract's entities" / "skin/ has ONLY the contract's routes" — the un-owned `Other` entity/usecase/view never enter; the routes barrel carries exactly the contract routes |
| `zfa slice worktree <id>` opens a worktree at the slice root | **PROVED** (fast suite) | `slice_worktree_capability_test.dart` "opens a worktree at the slice root on branch slice/<id>": the slice root is a git working tree on `slice/login`, committed clean, working tree = engine/skin/contract/receipts (never the parent's `lib/`), parent linkage in `.slice/parent.json` |
| `zfa slice check <id>` exits 0 with a compliance report; exit 1 with a "files outside slice" report | **PROVED** (fast suite) | `slice_check_capability_test.dart`: compliant slice → exit 0 + `receipts/slice-check.json` verdict `compliant`; smuggled `engine/entities/hacker/`, `skin/views/rogue_view.dart`, root `exploit.dart` → exit 1 with the files named (`engine-entity` / `skin-route` / `outside-slice`) |
| `zfa tdd run <id>` inside the slice worktree produces the same `tdd/journal.json` as in the parent repo (paths rewritten) | **PROVED at the journal-writer level (fast suite)** — the driver's journal is written by `TddTransaction` (bug #828, unchanged by this spec): the record written from `<slice>/specs/login` equals the parent's record (same `feature` axis) at the same relative structure `specs/<feature>/tdd/journal.json`, and `ProjectRoot.find(anchorDir: 'specs')` from inside the worktree resolves to the SLICE root (the run/run-engine/run-skin feature-dir join). The full spawned-driver `zfa tdd run` E2E is slow-tier subprocess territory (dart-test spawns); NOT run in the fast tier here | `slice_worktree_capability_test.dart` "zfa tdd run journal equivalence …" + "the tdd driver resolves its project root INSIDE the worktree" |

## Known scope notes (honest)

- The 1114 manifest is a NEW feature-centric model
  (`slice.manifest.v2`, `FeatureSliceManifest`) written by
  compose/worktree/check. The legacy 043/073 `SliceManifest`
  (entity-centric) is untouched — it serves the cut/merge/export
  pipeline, and rewriting it in place would break that contract in the
  same PR (hard constraint: one PR).
- `zfa slice worktree` roots a dedicated git repository AT the slice
  (`.zfa/` is gitignored in the parent). A plain `git worktree add`
  checks out the ENTIRE parent repo — the opposite of the slice's
  purpose — so the dedicated repo + `.slice/parent.json` linkage is the
  documented implementation of "a git worktree rooted at the slice".
- `SLICE_XRAY_COHERENCE.md` (in `~/Developer/zik_zak`) is not present on
  this machine; the issue text's summary of gaps 1, 3, 6 + the worktree
  scoping was the working brief.
