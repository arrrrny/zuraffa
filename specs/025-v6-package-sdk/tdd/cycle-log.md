# TDD Cycle Log: v6 Package SDK

Red-green-refactor record for spec 025, branch `025-v6-package-sdk`.
Baseline before cycle 1: `dart analyze` 111 issues / 23 pre-existing errors
(all in `zikzak_session/` + `examples/mcp_demo/` — missing git submodule
content, documented since spec 038); fast suite green on master; `.gym/**`
and the spec-025 examples excluded from root analysis (see cycle 10).

## Cycle 1 — PackageMode detector (U1, U1b)

- **RED**: `test/package_sdk/package_mode_test.dart` →
  `Error: Undefined name 'PackageMode'` (class absent), 1 loading failure.
- **GREEN**: `lib/src/package/package_mode.dart` — `zfa.package_mode` marker
  detection via `yaml` (marker file at the time: `build.yaml`). 6/6 pass.
- **Refactor**: none needed.

## Cycle 2 — PackageModule + engine lifecycle + compatibility gate (U5–U12)

- **RED**: `test/package_sdk/package_module_test.dart` →
  `Type 'PackageModule' not found`, `Undefined name 'version'`,
  `The getter 'packageName' isn't defined` (contract + hooks absent).
- **GREEN**:
  - `lib/src/core/module/package_module.dart` — `PackageModule` contract
    (`packageName`, `zuraffaSdkConstraint`, agent tools hook).
  - `zuraffa_plugin.dart` — default no-op `onReady`/`onDispose` (source
    compatible for every existing subclass).
  - `engine.dart` — `ready()` (once, insertion order; requires bootstrap),
    `shutdown()` (reverse order, idempotent), `activeModuleIds`,
    `registerPackage()` with the FR-015 gate.
  - `lib/src/package/package_compatibility.dart` — caret/range/exact
    constraint parsing; major mismatch → incompatible; newer minor →
    warning.
  - Fixed a test-double bug found green-up (two modules registering the
    same `String` type → instance names).
- **Regression check**: `test/core/module/` 39/39 green — engine changes
  are additive.

## Cycle 3 — Compatibility matrix (U10, U11) — born green

Implementation was driven red by U12 in cycle 2 (`registerPackage`
rejection test); this cycle adds the full coverage matrix
(`^6.1` short forms, both mismatch directions, unparseable constraint →
warning). 9/9. Teeth: the matrix pins exact statuses per input pair.

## Cycle 4 — DI plugin package mode (U13–U15)

- **RED**: `package_registrar_test.dart` → U13/U14/U15 fail: registrar
  missing while app-mode artifacts (`service_locator.dart`) are emitted
  (assertions name the missing file). U13b (app mode unchanged) passed —
  existing behavior.
- **GREEN**:
  - `PackageMode.isEnabledForOutput(outputDir)` — walk-up detection from
    the generator's output dir to the project root.
  - `PackageRegistrarBuilder` — emits
    `register<Pascal>Package(ZuraffaDIContainer di)` aggregating
    `registerAll*` per category.
  - `di_plugin.dart` — package-mode branch: registrar instead of the
    `setupDependencies` main index + service locator; per-category index
    files unchanged (context-free); registrar regenerated from on-disk
    category indexes (multi-entity single pass, idempotent; force-replaces
    the scaffold stub).
- **Regression**: `test/plugins/di/` 6/6 green.

## Cycle 5 — App-artifact suppression + parity (U16–U18)

- **RED**: U16 (plugin filter) and U17 (app shell refusal) fail — no
  package-mode awareness. U18 (parity) passed immediately: cycle 4's DI
  branch already gives byte-identical domain/data emission — born green
  with cycle-4 red as its driving evidence; the test additionally pins the
  ≥90% SC-003 bound (actual: 100% on shared layers) and the
  registrar-vs-locator asymmetry.
- **GREEN**: `PluginManager.resolvePlan` filters
  `route/view/presenter/controller/app_shell` when the marker is present
  (single choke point `zfa make` flows through); `AppShellCommand` refuses
  in package mode. 4/4.
- **Regression**: `test/core/plugin_system/` 17/17; `test/plugins/app_shell/`
  75/75.

## Cycle 6 — PackageScaffold (U2–U4b, FR-014)

- **RED**: `Error when reading 'lib/src/package/package_scaffold.dart'`
  (class absent).
- **GREEN**: `package_scaffold.dart` — full standard layout (pubspec with
  v6 constraints, marker config, analysis options, domain/data dirs,
  module stub, registrar stub, barrel, smoke test, README); existing-dir
  refusal without touching content (FR-014); invalid-name refusal before
  any write; `--zuraffa-path` path-dep swap. 9/9 after fixing one test
  bug (fake `--zuraffa-path` pointed at a non-existent dir — the
  validation is correct, the test fixture wasn't).

## Cycle 7 — `zfa package create` command (U19–U21)

- **RED**: `Type 'PackageCommand' not found` + registration assertions.
- **GREEN**: `lib/src/commands/package_command.dart` (`package create`
  subcommand: `--output/--description/--zuraffa-path/--dry-run`),
  registered in `CliRunner`, help text updated. 6/6.

## Cycle 8 — Agent tools bridge (U22–U24, U28, U29)

- **RED**: `Error when reading 'lib/src/package/package_agent_tools.dart'`.
- **GREEN**: `package_agent_tools.dart` — `PackageAgentTools.namespaced` /
  `registerInto` (namespace prefixing via a delegating `McpTool` wrapper),
  `PackageUseCaseTool<T>` (DI-resolved invocation, errors as `isError`
  results). Barrel exports extended. 9/9.

## Cycle 9 — Auto-registration proof (U25–U27, SC-002) — born green

The acceptance-level proof that a consuming app resolves a package's
datasource + usecase with zero registration code. All mechanics were
driven red in cycles 2/4/8; this cycle pins the SC-002 story end-to-end
(plus module-only-package lifecycle and init-failure propagation). 5/5
with justification recorded.

## Cycle 10 — E2E (U30, SC-001) — TWO MISFIRES FOUND AND FIXED

- **RED (first run)**: build exits 0 but the zorphy codegen part is
  missing — a genuine misfire, not a test bug.
- **Root cause 1 (my bug)**: build_runner **rejects unknown top-level keys
  in build.yaml** (`Unrecognized keys: [zfa]`, exit 78 on every build).
  The planned marker location was invalid. **Fix**: marker moved to a
  zfa-owned `zfa.yaml` (plan.md D1 amended); scaffold's build.yaml carries
  only build_runner-legal config. Marker detection, scaffold, and all
  fixtures updated (cycles 1/4/5/6 test fixtures re-pointed).
- **Root cause 2 (pre-existing bug)**: `zfa build`'s failure path printed
  the error but **exited 0** — the e2e's build step "passed" while the
  build had actually failed (the silent-0-exit class from issue #276).
  Additionally `zfa build --dry-run` invoked build_runner unconditionally.
  **Fix**: failure paths now `exit(1)`; dry-run stops after the pre-flight
  preview. `test/commands/build_command_test.dart` 5/5 (its dry-run tests
  previously passed vacuously through the swallowed exit code — verified
  against clean master before/after).
- **GREEN (second run)**: full pipeline passes — scaffold → pub get →
  analyze (zero errors) → entity create → make (registrar emitted, no app
  artifacts) → `zfa build` (codegen + embedded analyze clean) →
  scaffolded smoke tests pass. **Total elapsed 48.3s** (SC-001 bound: 5
  min; phase 1 alone: 2.2s).

## Cycle 11 — Reference package + demo app + guide (US7, SC-004)

- Built `examples/notes_package` **through the real zfa pipeline**
  (dogfood: create → entity → make `--mock --use-mock` → build → test).
  Two more dogfood findings fixed:
  1. Unquoted package descriptions containing `:` broke the generated
     pubspec YAML → descriptions now always quoted/escaped (+ U3c
     regression test).
  2. `notes_package` scaffolded as `NotesPackagePackageModule` (stutter) →
     shared `PackageNames` helper folds a redundant trailing `Package`
     (`NotesPackageModule` / `registerNotesPackage`), used by BOTH the
     scaffold and the DI registrar builder so the names can never diverge.
- `buildAgentTools(di)` refactor: tools need the consuming container at
  build time — `agentTools` getter became
  `buildAgentTools(ZuraffaDIContainer di)`; `registerInto` takes the
  container. Tests updated; the reference module wires a real
  `notes_package.get_note` tool over `GetNoteUseCase`.
- `examples/reference_package_app` — demo app + SC-002/FR-008/FR-006
  proof tests (3/3) and a runnable `bin/app.dart`; `dart run bin/app.dart`
  resolves via auto-DI and invokes the namespaced tool end-to-end.
- `docs/writing_zuraffa_packages.md` — the guide; every command in it was
  executed during this cycle.
- Reference package: analyze clean, tests 2/2. Committed with generated
  parts (example ships a complete package; its .gitignore documents the
  flip for real packages).

## Suite status after all cycles

See `tdd/verification.md` for the full per-directory fast-suite tally and
the integration-tier e2e evidence.
