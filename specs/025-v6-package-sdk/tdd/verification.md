# TDD Verification: v6 Package SDK

Audit report for `/speckit.tdd.verify` — spec 025, branch `025-v6-package-sdk`.

**Verdict: PASS.** Every success criterion is backed by a green run through its real entry point (the `zfa` CLI for SC-001, a live engine + package module for SC-002, a byte-level generator comparison for SC-003, and a dogfooded reference package + demo app for SC-004). Red evidence exists for every substantive cycle; two born-green cycles are justified in `cycle-log.md`; the e2e cycle found and fixed two real defects (one mine, one pre-existing). The repo suite is unregressed.

## 1. Suite status

| Command | Result |
|---------|--------|
| `dart test test/package_sdk/` (fast, new feature suite) | **63 passed, 0 failed** (8 files) |
| `dart test --preset=integration test/package_sdk/package_e2e_test.dart` | **1 passed** — full pipeline: CLI scaffold → `dart pub get` → `dart analyze` (zero errors) → `zfa entity create` → `zfa make` (registrar emitted, no app artifacts) → `zfa build` (codegen + embedded analyze clean) → scaffolded smoke tests → **total 48.3s** (SC-001 bound: 5 min) |
| `dart analyze` (repo root) | **Byte-identical to the master baseline** (on the original base `d27c3d2b`: 111 issues / 23 errors; after rebasing onto `c389dfd9`: 112 issues / 23 errors — the delta is master's own new info, not this feature; `diff` of full output empty in both cases) (`diff` of error lines empty; all pre-existing in `zikzak_session/` + `examples/mcp_demo/`, documented since spec 038). The new `examples/notes_package` + `examples/reference_package_app` are excluded from the ROOT context (independently-resolved sub-packages — the established `.gym/**` pattern) and are analyzed GREEN from inside their own directories (`dart analyze` → "No issues found!" in each). |
| Fast suite, run directory-by-directory (single full invocations produce a pathological ~8 GB kernel artifact in this sandbox — documented since spec 021) | Original base: **2,542 passed / 0 failed / 1 skipped**. After rebase onto `c389dfd9` (master removed `test/routing/` and grew dda/shadcn/tdd suites): **2,676 passed / 0 failed / 1 skipped** — agent 144, app_update 6, biometrics 7, cli 139, clipboard 6, commands 235, config 10, core 572 (+1 skip), dda 80, device 6, domain 18, graphql 192, i18n 11, logging 6, mcp 71, migration 20, plugins: api 30, app_shell 75, benchmark 106, datasource 5, di 6, gym 15, method_append 6, mock 37, module 2, provider 4, repository 7, route 35, service 8, shadcn 56, sqlite 8, state 2, strategy 26, sync 31, tdd 37, tui 66, usecase 17, xray 128, test_builder 5, toggle 3, package_sdk 63, regression 78, secure_storage 11, session 20, share 5, state 99, utils 72 |
| `dart format --set-exit-if-changed lib test` (the CI format gate) | **exit 0 — zero formatting diffs** (re-verified after the rebase) |
| Reference package (`examples/notes_package`) | `dart analyze` no issues; `dart test` 2/2; built via the real zfa pipeline (dogfood) |
| Demo app (`examples/reference_package_app`) | `dart analyze` no issues; `dart test` 3/3; `dart run bin/app.dart` resolves via auto-DI and invokes `notes_package.get_note` end-to-end |

**Known pre-existing issue (not caused by this feature, re-confirmed):** `test/plugins/mcp/mcp_server_plugin_test.dart` hangs when run as a full file in this sandbox (SSE-server lifecycle) — identical to master behavior documented in specs/021; individual tests pass. Not addressed: out of scope (no changes to that subsystem).

## 2. Acceptance criteria — proven or not

| SC | Claim | Status | Evidence |
|----|-------|--------|----------|
| SC-001 | Scaffold + static analysis + build pipeline < 5 min, zero manual edits | **PROVEN** | `test/package_sdk/package_e2e_test.dart` (integration tier): `zfa package create sc001_pkg --zuraffa-path <repo>` → `dart pub get` → `dart analyze` exit 0 → `zfa entity create -n Product …` → `zfa make Product datasource repository usecase di` (registrar emitted at `lib/src/di/sc001_pkg_package_registrar.dart`; `service_locator.dart`, `routing/`, `presentation/` asserted ABSENT) → `zfa build` exit 0 with `product.zorphy.dart` generated and embedded analyze clean → `dart test` green on the scaffolded harness. **Elapsed 48.3s** (phase 1: scaffold+pubget+analyze = 2.2s). Cycle-10 first run was RED for the right reason (missing codegen part) and exposed both defects below — the green run is honest, not vacuous: `zfa build` failures now exit non-zero (defect 2), so a silently-failing build can no longer pass this test. |
| SC-002 | Consuming app resolves datasource + usecase with no manual registration | **PROVEN** | Three independent proofs: (1) `test/package_sdk/package_auto_registration_test.dart` — the app code is exactly `registerPackage(module)` + `bootstrap()`; the container resolves `NoteRemoteDataSource`-shaped contributions and the usecase; without the module nothing registers (import-scoped); two packages merge conflict-free. (2) `examples/reference_package_app/test/consume_test.dart` — same story against the REAL generated package. (3) `examples/reference_package_app/bin/app.dart` — runnable `main()` demo. Zero registration lines anywhere in app code. |
| SC-003 | ≥90% of domain/data identical app-vs-package context | **PROVEN (actual: 100%)** | `test/package_sdk/package_mode_filter_test.dart` U18: same entity generated in both contexts; every domain/data file byte-identical (identical file SET asserted too); only the DI tail differs (package: registrar; app: `setupDependencies` + `service_locator.dart`), asserted by path presence/absence. |
| SC-004 | Guide + reference package enable end-to-end build & consume | **PROVEN (automated walkthrough)** | The reference package was built BY FOLLOWING the guide's exact commands (cycle 11 — including the two dogfood defects the guide's flow surfaced, both fixed); the demo app consumes it with analyze clean, tests green, and a runnable main proving resolution + namespaced tool invocation. The guide documents every flag used. The "independent reviewer < 30 min" framing is operationalized as: every command in the guide is verified runnable end-to-end (scaffold→consume took ~2 minutes of wall time in cycle 11 after the pipeline was warm). |

## 3. Behavior coverage

All 37 test-list behaviors (A1–A4, U1–U30 + sub-behaviors) are `DONE` with named tests in `tdd/test-list.md`. Red evidence per cycle in `tdd/cycle-log.md`:

- Cycle 1 (U1/U1b): compile-red (`Undefined name 'PackageMode'`).
- Cycle 2 (U5–U12): compile-red (`Type 'PackageModule' not found`); U12's incompatible-module rejection has full assertion red semantics through the gate implementation.
- Cycle 3 (U10/U11): born-green coverage matrix — implementation was driven red by U12 in cycle 2; matrix pins exact statuses per input pair (both mismatch directions, short forms, unparseable).
- Cycle 4 (U13–U15): assertion-red — U13/U14/U15 failed with the registrar missing while app-mode artifacts were emitted; U13b (app mode unchanged) green throughout (regression guard).
- Cycle 5 (U16–U18): U16/U17 assertion-red (no filter, no guard); U18 born-green via cycle 4's red with the ≥90% bound and the asymmetry assertions adding teeth.
- Cycle 6 (U2–U4b): compile-red; FR-014 refusal behaviors asserted (existing dir untouched, invalid name writes nothing).
- Cycle 7 (U19–U21): compile-red; duplicate-target CLI run asserts exit non-zero + content untouched.
- Cycle 8 (U22–U24/U28/U29): compile-red; collision matrix (two packages coexist / same package twice throws).
- Cycle 9 (U25–U27): born-green acceptance proof (mechanics red in cycles 2/4/8); includes module-only package, two-package merge, init-failure propagation.
- Cycle 10 (U30): first run RED (missing codegen part) — **two defects found**: (1) build_runner rejects `zfa:` in build.yaml → marker moved to zfa.yaml (plan D1 amended); (2) pre-existing silent-exit-0 on build failure + dry-run invoking build_runner → both fixed; build tests 5/5 after (they previously passed vacuously through the swallowed exit code — verified against clean master).
- Cycle 11 (US7): dogfood run of the guide surfaced (3) unquoted `:` descriptions breaking pubspec YAML (fixed + U3c regression test) and (4) `NotesPackagePackageModule` name stutter (fixed via shared `PackageNames` used by scaffold AND registrar builder so names cannot diverge).

FR traceability: FR-001 (U2–U4b, U19–U21), FR-002 (U30/SC-001), FR-003 (U13 no-app-artifacts + U16 filter + U17 shell refusal), FR-004 (U13/U15), FR-005 (U25/U26 + demo app), FR-006 (U7/U8/U27 + module contract), FR-007 (U9/U27), FR-008 (U22–U24/U29), FR-009 (U28), FR-010 (U18 parity + same-command e2e), FR-011 (U1/U1b marker + U2b), FR-012 (U14 multi-entity single-pass idempotent), FR-013 (guide + reference + demo, dogfooded), FR-014 (U20 + scaffold refusal tests), FR-015 (U10–U12 + registerPackage gate).

## 4. Mutation sampling (no mutation tool wired — deliberate mutants)

| Mutant | Expected kill | Result |
|--------|---------------|--------|
| M1: remove the package-mode branch in DiPlugin (always app emission) | U13 | **Killed** — `package registrar must be emitted in package mode` (cycle-4 red run IS this mutant) |
| M2: detection reads marker from build.yaml top-level key (the original D1 design) | U30/SC-001 | **Killed by reality** — build_runner rejects the key; e2e failed with missing codegen (cycle-10 red). This mutant motivated the zfa.yaml design. |
| M3: `registerInto` skips namespacing (registers raw tool names) | U22/U24 | **Killed** — `registry.find('fetch_thing')` must be null while `pkg_a.fetch_thing` resolves |
| M4: compatibility check compares only strings (no parse) | U10/U11 | **Killed** — `^6.2.0` vs `6.1.0` must be warning, not compatible; `^7.0.0` must name both versions |
| M5: scaffold overwrites an existing directory | FR-014/U20 | **Killed** — CLI + scaffold tests assert exit non-zero + `keep.txt` intact + no pubspec written |

## 5. Honest gaps and flagged pre-existing issues

1. **Agent-tool codegen is runtime + reference pattern, not per-usecase generation.** The module's `buildAgentTools` + `PackageUseCaseTool` + `PackageAgentTools.registerInto` bridge is complete and tested (FR-008/FR-009 at the package-SDK level), and the reference package demonstrates wiring a tool over a generated usecase — but `zfa make --agent` (generating tool wrappers automatically per usecase) is spec 029 / issue #385 territory and is NOT implemented here. The spec's own assumption section defers that infrastructure to #385/#386; the guide states this boundary explicitly.
2. **`zfa build` exit-code + dry-run fixes (pre-existing defects, fixed here).** `zfa build` exited 0 after a failed build_runner run, and `zfa build --dry-run` invoked build_runner for real — both pre-existing on master (the #276 self-healing tests passed vacuously through the swallowed exit code). SC-001's honesty depends on exit codes, so both are fixed in this PR: failure paths exit 1; dry-run stops after the pre-flight preview. `test/commands/build_command_test.dart` 5/5 on branch, 5/5 verified on clean master before the fix (i.e., the fix repairs masked behavior without changing asserted contracts).
3. **Marker location changed vs. plan (design amendment, documented).** `build.yaml` cannot carry the marker (build_runner schema validation). The marker lives in zfa-owned `zfa.yaml`; plan.md D1 records the amendment with the misfire evidence. The spec's FR-011 requirement ("package maintains its own build configuration that signals package-mode") is satisfied by the `zfa.yaml` + `build.yaml` pair; US6-S2's "build configuration contains a package-shape marker" is met by `zfa.yaml` being that configuration.
4. **Reference package commits generated parts.** `examples/notes_package` ships `note.zorphy.dart`/`note.g.dart` so the demo app consumes a complete package on a fresh clone; its `.gitignore` documents how to flip back to ignoring generated code in real packages. The repo's own build.yaml already excludes `example/**` from its codegen, and the two new examples are excluded from ROOT analysis (independently-resolved sub-packages — same rationale as `.gym/**`), each analyzing green from inside its own directory.
5. **Conflict resolution on identity collisions** (spec edge case) delegates to the existing container semantics: `register*` with `override: false` throws a clear StateError during `bootstrap()`. The spec explicitly deferred the exact strategy to planning; the guide documents the behavior. No new merge/override machinery was added.
6. **The `pubspec.lock` churn seen locally is NOT part of this PR** — reverted; the PR adds no dependencies. The `dart format .` run also touched pre-existing drifted files outside the CI gate's scope (`lib`/`test` only); those unrelated changes were reverted — the actual gate (`dart format --set-exit-if-changed lib test`) exits 0.
