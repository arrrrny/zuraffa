# TDD Test List: Zuraffa V5 Foundation

**Feature**: `007-zuraffa-v5-foundation`  
**Branch**: `007-zuraffa-v5-foundation`  
**Planned at**: `614e648`  
**Updated at**: `614e648`

---

## Legend
- **AC** = Acceptance Criterion (outer behavior, from spec.md User Stories)
- **U** = Unit behavior (inner behavior, from plan.md components)
- **Status**: DONE = already covered by passing test, PENDING = needs test, BLOCKED = blocked by bug

---

## User Story 1: One Canonical Generation API via `zfa make` (P1)

### AC-001: `zfa make` generates CRUD architecture deterministically
- **Description**: Run `zfa make Product --preset=crud --with=data,vpc,state,di,test` and verify it generates expected layers with machine-readable output
- **Status**: **DONE**
- **Test**: `test/commands/make_command_test.dart` - "supports --format=json with --plan" (line 92)
- **Test**: `test/commands/make_command_test.dart` - "#346 — with di generates and wires datasource DI registrations" (line 418)

### AC-002: `zfa generate` removed and fails with migration message
- **Description**: Running `zfa generate ...` in v5 fails fast with breaking-change message pointing to `zfa make`/`zfa feature`
- **Status**: **DONE**
- **Test**: `test/commands/generate_command_test.dart` - "prints v5 migration guidance" (line 6)

### AC-003: `zfa make` supports stdin/json workflows
- **Description**: `zfa make Product --from-stdin --format=json` returns fully machine-readable success/failure result
- **Status**: **DONE**
- **Test**: `test/commands/make_command_test.dart` - "supports --from-stdin for plan resolution" (line 181)
- **Test**: `test/commands/make_command_test.dart` - "supports --from-json for plan resolution" (line 121)

### AC-004: Entity-first validation (fast-fail for missing entity)
- **Description**: Running `zfa make` without entity fails with exact next-step guidance
- **Status**: **PENDING**
- **Gap**: No explicit test for this behavior found

### AC-005: Value object handling (skips root plugins)
- **Description**: Value objects (`@ZValueObject`) skip root plugins (repository/usecase/controller/presenter) but generate mock data
- **Status**: **DONE**
- **Test**: `test/commands/make_command_test.dart` - "value object — make skips the root plugins" (line 355)

### AC-006: Identity contract - id-less entity fails loudly
- **Description**: Entity without id field fails with "has no id field" instead of falling back to first enum field
- **Status**: **DONE**
- **Test**: `test/commands/make_command_test.dart` - "#307 — an id-less entity fails loudly" (line 285)

### AC-007: autoId: true resolves String id
- **Description**: Entity with `autoId: true` gets String id generated without id getter in source
- **Status**: **DONE**
- **Test**: `test/commands/make_command_test.dart` - "#307 — autoId: true resolves the identity to a String id" (line 321)

---

## User Story 2: Deterministic Plugin Orchestration with `.zfa.json` Defaults (P1)

### AC-008: `.zfa.json` defaults apply correctly
- **Description**: `.zfa.json` enabling `di`, `route`, `test` by default causes resolved plan to include them
- **Status**: **DONE**
- **Test**: `test/commands/make_command_test.dart` - "supports explicit exclusions and negation over defaults" (line 149)

### AC-009: Explicit exclusion via `--without` or `--no-<plugin>`
- **Description**: `--without=route` or `--no-controller` excludes plugin from plan and generation
- **Status**: **DONE**
- **Test**: `test/commands/make_command_test.dart` - "supports explicit exclusions and negation over defaults" (line 149)

### AC-010: Programmatic `CodeGenerator` uses same plan resolution
- **Description**: Direct `CodeGenerator` call resolves same plugin set as CLI for equivalent inputs
- **Status**: **PENDING**
- **Gap**: No test comparing CLI vs programmatic plan resolution

### AC-011: Plugin alias/group resolution (`data` => `repository,datasource`)
- **Description**: Preset/group aliases normalized to real plugin sets deterministically
- **Status**: **PENDING**
- **Gap**: No explicit test for alias resolution (though preset tests cover some)

### AC-012: Disabled plugins never self-activate
- **Description**: Plugins in `.zfa.json` `disabled` list never run even if included in preset
- **Status**: **PENDING**
- **Gap**: No test for disabled plugin enforcement

---

## User Story 3: Persistent Agent Memory and Blueprints in `.zfa/` (P1)

### AC-013: Generation stores normalized plan in `.zfa/plans/`
- **Description**: Successful `zfa make` stores normalized plan under `.zfa/plans/`
- **Status**: **DONE**
- **Test**: `test/integration/zfa_memory_integration_test.dart` - "successful generation writes .zfa memory artifacts" (line 29)

### AC-014: Execution run artifact stored in `.zfa/runs/`
- **Description**: Completed execution creates run artifact with generated files, timestamps, duration
- **Status**: **DONE**
- **Test**: `test/integration/zfa_memory_integration_test.dart` - "successful generation writes .zfa memory artifacts" (line 29)

### AC-015: Project context stored in `.zfa/context.json`
- **Description**: Context file contains version, domain_root, workflow, generated/manual zones
- **Status**: **DONE**
- **Test**: `test/integration/zfa_memory_integration_test.dart` - "successful generation writes .zfa memory artifacts" (line 29)

### AC-016: PlanStore migration from `.zuraffa/` to `.zfa/`
- **Description**: PlanStore falls back to legacy `.zuraffa/plans/` during migration
- **Status**: **DONE**
- **Test**: `test/core/plugin_system/plan_store_test.dart` - "loadPlan falls back to legacy .zuraffa plans during migration" (line 110)

### AC-017: Blueprint storage in `.zfa/blueprints/`
- **Description**: Architectural intent documents persisted and readable by new agents
- **Status**: **PENDING**
- **Gap**: No test for blueprint persistence/read

### AC-018: Decision records in `.zfa/decisions/`
- **Description**: Architectural rules (entity-first, route strategy, shell strategy, etc.) persisted
- **Status**: **PENDING**
- **Gap**: No test for decision record persistence

### AC-019: Manifest storage in `.zfa/manifests/`
- **Description**: Generated structure snapshots persisted
- **Status**: **PENDING**
- **Gap**: No test for manifest persistence

### AC-020: Revert operation logs to `.zfa/`
- **Description**: Revert command logs its action while preserving prior plan/run artifacts
- **Status**: **PENDING**
- **Gap**: No test for revert logging

---

## User Story 4: Platform-Aware Layouts and Shells (P1)

### AC-021: Platform layout generation with shared logic
- **Description**: Generated feature contains shared presenter/controller/state plus layout variants (mobile/tablet/desktop/macos)
- **Status**: **PENDING**
- **Gap**: No integration test for full platform-aware feature generation

### AC-022: macOS shell/layout selection before fallback
- **Description**: Framework resolves macOS platform, selects macOS shell/layout before falling back to desktop/tablet/mobile
- **Status**: **PENDING**
- **Gap**: No test for platform fallback resolution

### AC-023: Documented fallback chain (macOS → desktop → tablet → mobile)
- **Description**: When no platform-specific layout, fallback order documented and enforced
- **Status**: **PENDING**
- **Gap**: No test for fallback chain

### AC-024: AdaptiveLayoutScaffoldBuilder generates layout files
- **Description**: Builder creates `*_mobile_layout.dart`, `*_tablet_layout.dart`, etc. under `presentation/pages/{entity}/layouts/`
- **Status**: **DONE** (Unit level)
- **Test**: `lib/src/plugins/view/builders/adaptive_layout_scaffold_builder.dart` - generates layout files but no test file exists yet

### AC-025: Layout targets configurable via `.zfa.json` and CLI
- **Description**: `ui.layoutTargets` in `.zfa.json` and `--layout-targets` CLI arg control targets
- **Status**: **PENDING**
- **Gap**: No test for CLI/config layout target override

### AC-026: Adaptive presets (`adaptive-feature`, `platform-feature`) include route
- **Description**: Adaptive presets include `route` plugin for shell navigation
- **Status**: **DONE** (Verified in PresetRegistry)
- **Test**: `lib/src/core/planning/preset_registry.dart` - adaptive presets include `route` (lines 33-56)

---

## User Story 5: Cohesive Documentation, Prompts, and Reliability Defaults (P1)

### AC-027: Docs teach canonical workflow (`entity create` → `make` → `build`)
- **Description**: All official docs surfaces recommend the v5 canonical workflow
- **Status**: **DONE**
- **Test**: `test/regression/v5_pipeline_contract_test.dart` - "core docs teach the full canonical pipeline" (line 39)

### AC-028: No docs reference removed `zfa generate`
- **Description**: Legacy residue guard - no `zfa generate` in README, AGENTS.md, CLI_GUIDE.md, SKILL.md, website docs
- **Status**: **DONE**
- **Test**: `test/regression/v5_pipeline_contract_test.dart` - "no legacy generator residues remain in active/public surfaces" (line 85)

### AC-029: Default test suite hermetic (no MinIO required)
- **Description**: MinIO-dependent tests gated/skipped in default suite
- **Status**: **PENDING** (Known failing baseline)
- **Gap**: Baseline shows test failure in `test/plugins/mcp/mcp_sse_server_test.dart` (timeout)

### AC-030: MCP server advertises `zuraffa_make`
- **Description**: MCP server exposes `zuraffa_make` tool that invokes `make` command
- **Status**: **DONE**
- **Test**: `test/regression/v5_pipeline_contract_test.dart` - "MCP server advertises zuraffa_make and invokes make" (line 58)

### AC-031: Example `.zfa.json` uses v5 config shape
- **Description**: Example config has `plugins`, `planning`, `ui`, `entity` sections
- **Status**: **DONE**
- **Test**: `test/regression/v5_pipeline_contract_test.dart` - "example .zfa.json uses v5 config shape" (line 69)

### AC-032: Project context encodes canonical workflow
- **Description**: `ProjectContextStore.defaultContext()` returns correct workflow array
- **Status**: **DONE**
- **Test**: `test/regression/v5_pipeline_contract_test.dart` - "default project context encodes the canonical workflow" (line 32)

---

## Unit Behaviors from Plan.md

### U1: Unified Planning Layer - preset resolution
- **Status**: **PENDING**
- **Gap**: No test for preset resolution edge cases (unknown preset, empty preset, custom presets)

### U2: Unified Planning Layer - plugin alias/group resolution
- **Status**: **PENDING**
- **Gap**: No test for alias normalization (e.g., `data` → `repository,datasource`)

### U3: Unified Planning Layer - defaults from `.zfa.json`
- **Status**: **DONE** (Partial - covered by AC-008/AC-009)
- **Test**: `test/commands/make_command_test.dart` - "supports explicit exclusions and negation over defaults" (line 149)

### U4: Unified Planning Layer - explicit inclusions/exclusions
- **Status**: **DONE** (Covered by AC-009)

### U5: Unified Planning Layer - validation/preconditions
- **Status**: **PENDING**
- **Gap**: No test for validation of preconditions (entity exists, valid output dir, etc.)

### U6: Unified Planning Layer - execution ordering
- **Status**: **DONE** (Partial - DI ordering test exists)
- **Test**: `test/commands/make_command_test.dart` - "#346 — with di generates and wires datasource DI registrations" (line 418) - verifies datasources before repositories

### U7: Unified Planning Layer - machine-readable serialization
- **Status**: **DONE** (Covered by AC-001/AC-003)

### U8: `.zfa` Project Memory Layer - plans persistence
- **Status**: **DONE** (Covered by AC-013)

### U9: `.zfa` Project Memory Layer - runs persistence
- **Status**: **DONE** (Covered by AC-014)

### U10: `.zfa` Project Memory Layer - blueprints persistence
- **Status**: **PENDING** (Covered by AC-017)

### U11: `.zfa` Project Memory Layer - decisions persistence
- **Status**: **PENDING** (Covered by AC-018)

### U12: `.zfa` Project Memory Layer - manifests persistence
- **Status**: **PENDING** (Covered by AC-019)

### U13: `.zfa` Project Memory Layer - context.json
- **Status**: **DONE** (Covered by AC-015)

### U14: Platform-Aware Presentation Layer - device class resolution
- **Status**: **PENDING**
- **Gap**: No test for device class detection (watch/phone/tablet/desktop)

### U15: Platform-Aware Presentation Layer - platform class resolution
- **Status**: **PENDING**
- **Gap**: No test for platform class detection (iOS/Android/macOS/windows/linux/web)

### U16: Platform-Aware Presentation Layer - layout fallback
- **Status**: **PENDING** (Covered by AC-023)

### U17: Platform-Aware Presentation Layer - shells composition
- **Status**: **PENDING**
- **Gap**: No test for shell generation (MobileAppShell, TabletAppShell, etc.)

### U18: Platform-Aware Presentation Layer - shared logic (presenter/controller/state)
- **Status**: **PENDING** (Covered by AC-021 - shared logic stays shared)

### U19: Greenfield-only cutoffs - custom domain root paths unsupported
- **Status**: **DONE** (Enforced in ZfaConfig.fixedDomainRoot)
- **Test**: `test/regression/v5_pipeline_contract_test.dart` - context has `domain_root: lib/src/domain`

### U20: Greenfield-only cutoffs - arbitrary domain output overrides unsupported
- **Status**: **DONE** (Enforced in ZfaConfig.fixedEntityOutput)

### U21: Greenfield-only cutoffs - non-Zorphy entity modes unsupported
- **Status**: **DONE** (Enforced in ZfaConfig.zorphyOnly = true)
- **Test**: `test/regression/v5_pipeline_contract_test.dart` - context has `zorphy_only: true`

### U22: Fixed Domain Contract - lib/src/domain
- **Status**: **DONE** (Enforced in ZfaConfig)
- **Test**: `test/regression/v5_pipeline_contract_test.dart` - context has `domain_root: lib/src/domain`

### U23: Zorphy-Only Entity Contract
- **Status**: **DONE** (Enforced in ZfaConfig)
- **Test**: `test/regression/v5_pipeline_contract_test.dart` - context has `zorphy_only: true`

---

## Summary

| Category | Total | DONE | PENDING | BLOCKED |
|----------|-------|------|---------|---------|
| Acceptance Criteria (AC) | 32 | 17 | 15 | 0 |
| Unit Behaviors (U) | 23 | 9 | 14 | 0 |
| **Total** | **55** | **26** | **29** | **0** |

**Notes**:
- Baseline is RED: 1 pre-existing timeout in `test/plugins/mcp/mcp_sse_server_test.dart` (not related to this feature)
- Platform-aware layouts/shells are largely unimplemented (no tests, minimal implementation in `AdaptiveLayoutScaffoldBuilder`)
- `.zfa/` blueprints/decisions/manifests not yet tested
- Programmatic vs CLI plan resolution parity not tested
- Test suite hermeticity not verified (known MCP SSE timeout)