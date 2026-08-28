# Feature Specification: Feature-Flag System

**Feature Branch**: `030-feature-flag-system`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "feat(features): feature-flag system — enable/disable zuraffa features per build. This feature originates from GitHub issue #372 (https://github.com/arrrrny/zuraffa/issues/372). Implement a feature-flag system to enable/disable Zuraffa features per build (modular apps, A/B testing, locale-based, membership/subscription hooks)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Declare and toggle features in config (Priority: P1)

A zuraffa developer adds a `features:` section to `.zfa.json` listing each feature with an `enabled` boolean and optional `gates`. They can enable or disable a feature via CLI commands, and the configuration is validated at build time.

**Why this priority**: Without declarative feature configuration and CLI toggling, nothing downstream works — code generation, runtime lookup, and gate evaluation all depend on this foundation.

**Independent Test**: Add a `features:` block to `.zfa.json`, run `zfa feature list`, and verify each declared feature's name and enabled status appear. Run `zfa feature disable <name>` and verify the config is updated and `zfa feature list` reflects the change.

**Acceptance Scenarios**:

1. **Given** a zuraffa project with no `features:` section in `.zfa.json`, **When** the developer runs `zfa feature list`, **Then** the command exits 0 and lists no features (empty but valid).
2. **Given** a project with a `features:` block containing three features (two enabled, one disabled), **When** `zfa feature list` runs, **Then** all three features are listed with their correct enabled/disabled status.
3. **Given** a feature named `beta-scheduler` is declared and enabled, **When** the developer runs `zfa feature disable beta-scheduler`, **Then** `.zfa.json` is updated and `zfa feature list` shows `beta-scheduler` as disabled.
4. **Given** a feature is referenced in config but not declared anywhere, **When** `zfa build` runs, **Then** the build exits with a validation error naming the unknown feature.

---

### User Story 2 - Code generation respects feature flags (Priority: P1)

A zuraffa developer builds an app with some features disabled. The generated output (entities, routes, DI registrations, navigation entries) includes only the enabled features — disabled features leave no trace in the generated code.

**Why this priority**: This is the core value proposition — modular app building. Without it, feature flags are config-only decoration with no build impact.

**Independent Test**: Create two feature configurations (one with feature X enabled, one with X disabled), run `zfa build` for each, and diff the output. The build with X disabled must not contain any entities, routes, DI registrations, or navigation entries for X.

**Acceptance Scenarios**:

1. **Given** a project with feature `pro-analytics` enabled, **When** `zfa build` runs, **Then** the generated output includes all entities, routes, DI registrations, and navigation entries for `pro-analytics`.
2. **Given** the same project with `pro-analytics` disabled, **When** `zfa build` runs, **Then** the generated output contains zero references to `pro-analytics` — no entity classes, no route definitions, no DI bindings, no nav items.
3. **Given** a project with a flavor-based config (`flavor: free` disables pro features), **When** `zfa build --flavor free` runs, **Then** only the free feature-set is generated; a subsequent `zfa build --flavor pro` generates the full feature-set.
4. **Given** all features are enabled, **When** `zfa build` runs, **Then** the output is identical to a build with no `features:` section at all.

---

### User Story 3 - Runtime feature registry (Priority: P1)

A generated zuraffa app exposes a `FeatureFlags` registry that application code can query at runtime to determine whether a feature is active. The registry is populated from the build-time configuration and is available via dependency injection.

**Why this priority**: The runtime registry is what ties generated code to behavior — without it, the build-time flags have no runtime effect.

**Independent Test**: In a generated app, inject `FeatureFlags` and call `isEnabled('pro-analytics')` — it returns `true` when the feature was enabled at build time, `false` when disabled.

**Acceptance Scenarios**:

1. **Given** a build with feature `pro-analytics` enabled, **When** the app calls `FeatureFlags.isEnabled('pro-analytics')`, **Then** it returns `true`.
2. **Given** a build with feature `beta-scheduler` disabled, **When** the app calls `FeatureFlags.isEnabled('beta-scheduler')`, **Then** it returns `false`.
3. **Given** a build, **When** the app queries `FeatureFlags.enabledFeatures`, **Then** it returns the complete list of features enabled for that build.
4. **Given** a build, **When** the app calls `FeatureFlags.isEnabled('nonexistent')` with a feature not declared in config, **Then** it returns `false` (or throws a controlled error — implementation choice).

---

### User Story 4 - Gate evaluation: membership and locale (Priority: P2)

A zuraffa developer declares gate conditions on features (e.g., `membership:pro`, `locale:en-US,en-GB`). At runtime, the feature is only active if the gate conditions are met against the user's current context (subscription tier, app locale).

**Why this priority**: Gates extend flags from static per-build toggles to dynamic per-user/per-locale controls — essential for subscription apps and internationalized products.

**Independent Test**: Configure a feature with `membership:pro` gate, set the runtime user tier to `free`, verify `isEnabled` returns `false`; change tier to `pro`, verify it returns `true`. Repeat for locale gates.

**Acceptance Scenarios**:

1. **Given** a feature with `membership:pro` gate and the user's tier is `free`, **When** `FeatureFlags.isEnabled` is called, **Then** it returns `false`.
2. **Given** the same feature and the user's tier is `pro`, **When** `FeatureFlags.isEnabled` is called, **Then** it returns `true`.
3. **Given** a feature with `locale:en-US,en-GB` gate and the app locale is `fr-FR`, **When** `FeatureFlags.isEnabled` is called, **Then** it returns `false`.
4. **Given** a feature with `locale:en-US,en-GB` gate and the app locale is `en-US`, **When** `FeatureFlags.isEnabled` is called, **Then** it returns `true`.
5. **Given** a feature with both `membership:pro` and `locale:en-US` gates, **When** the user is `pro` tier but locale is `ja-JP`, **Then** the feature is disabled (all gates must pass).

---

### User Story 5 - A/B testing variant support (Priority: P2)

A zuraffa developer declares an A/B variant on a feature (e.g., `variant:a|b`). The generator emits both variants, and at runtime a variant-selection mechanism (remote config, provider) determines which variant is active for a given user session.

**Why this priority**: A/B testing is a key use case from the issue and enables data-driven feature rollout.

**Independent Test**: Configure a feature with `variant:a|b`, build, and verify both variant code paths exist in the output. At runtime, inject a mock variant provider that returns `a`, verify variant `a` is active.

**Acceptance Scenarios**:

1. **Given** a feature with `variant:a|b`, **When** `zfa build` runs, **Then** the generated output contains both variant code paths.
2. **Given** the app at runtime with a variant provider returning `a`, **When** the feature is queried, **Then** variant `a` is active.
3. **Given** a feature without any variant gate, **When** the feature is enabled, **Then** it has a single default variant (no A/B branching).

---

### User Story 6 - Pluggable feature flag provider (Priority: P3)

A zuraffa developer can replace the default static feature-flag resolution with a pluggable provider (e.g., a remote feature-flag service or entitlements backend). The provider interface is generated and injectable.

**Why this priority**: Remote resolution enables real-time A/B and subscription checks without rebuilding — important for mature apps but not needed for the initial MVP.

**Independent Test**: Register a custom `FeatureFlagProvider` that resolves from a local JSON file; verify `isEnabled` reflects the remote values instead of build-time defaults.

**Acceptance Scenarios**:

1. **Given** a custom `FeatureFlagProvider` is registered, **When** `FeatureFlags.isEnabled` is called, **Then** the result comes from the provider, not the build-time default.
2. **Given** no custom provider is registered, **When** `FeatureFlags.isEnabled` is called, **Then** the build-time static default is used.
3. **Given** a provider that throws an error, **When** `FeatureFlags.isEnabled` is called, **Then** the system falls back to the build-time default (fail-safe).

---

### Edge Cases

- What happens when a feature is enabled in config but its corresponding entity/code does not exist in the project?
- What happens when `gates` reference an unknown gate type (e.g., `tenant:xyz`)?
- What happens when two flavors define conflicting enabled/disabled states for the same feature?
- What happens when a feature is toggled after code has been generated — does `zfa build` detect staleness?
- What happens when the `features:` section contains invalid JSON or schema violations?
- What happens when a membership provider is unavailable at runtime (network failure, missing config)?
- What happens when locale is unavailable or unresolvable at runtime?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST parse and validate a `features:` configuration section in `.zfa.json` (or equivalent zuraffa config), rejecting unknown feature names and invalid gate syntax.
- **FR-002**: System MUST provide CLI commands (`zfa feature list`, `zfa feature enable <name>`, `zfa feature disable <name>`) to inspect and modify the feature configuration.
- **FR-003**: System MUST support flavor-based builds (`zfa build --flavor <name>`) where each flavor maps to a different feature-enabled/disabled configuration.
- **FR-004**: Code generation MUST include only the entities, routes, DI registrations, and navigation entries for features that are enabled — disabled features must produce no generated output.
- **FR-005**: System MUST generate a `FeatureFlags` registry class accessible via dependency injection, exposing `isEnabled(name)` and `enabledFeatures` APIs.
- **FR-006**: System MUST support `membership:<tier>` gates resolved through a pluggable provider interface (with a default local/mock implementation for testing).
- **FR-007**: System MUST support `locale:<locale-list>` gates evaluated against the app's current locale at runtime.
- **FR-008**: System MUST support `variant:<a|b|...>` gates for A/B testing, generating both variant code paths and selecting at runtime via a pluggable variant provider.
- **FR-009**: System MUST provide a `FeatureFlagProvider` interface that can be replaced by a custom implementation for remote/advanced resolution.
- **FR-010**: System MUST fall back to build-time defaults when a runtime provider throws or is unavailable (fail-safe behavior).

### Key Entities

- **FeatureFlag**: A named toggle with an enabled state, optional gates, and a generated runtime representation. Key attributes: name (string, unique), enabled (boolean), gates (list of gate conditions).
- **FeatureGate**: A condition attached to a feature that must be satisfied at runtime for the feature to be active. Variants: membership gate, locale gate, variant gate, custom gate.
- **FeatureFlagProvider**: An interface for resolving feature state at runtime, decoupled from build-time defaults.
- **Flavor**: A named build configuration that maps to a specific set of enabled/disabled features.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A zuraffa project with N features where M are disabled produces build output with zero references to the M disabled features (verified by grep/AST analysis).
- **SC-002**: `zfa feature list/enable/disable` commands complete in under 2 seconds for configs with up to 50 features.
- **SC-003**: A generated app with the default static registry can resolve any feature's enabled/disabled state via `isEnabled()` in O(1) time.
- **SC-004**: Switching between two flavors (`--flavor free` vs `--flavor pro`) produces distinct builds with exactly the expected feature sets, verified by automated diff.

## Assumptions

- The zuraffa config file (`.zfa.json`) already exists and is the source of truth for project configuration.
- Feature names are alphanumeric with hyphens (e.g., `pro-analytics`, `beta-scheduler`) and must be unique within a project.
- Gate syntax follows the colon-delimited convention (`membership:pro`, `locale:en-US,en-GB`, `variant:a|b`).
- The existing `zfa make` and `zfa build` pipelines will be extended, not replaced, to support feature-flag-aware generation.
- Remote feature-flag providers (LaunchDarkly, Firebase Remote Config, etc.) are out of scope for v1 — only the pluggable interface is required.
- A/B variant generation requires both code paths to be emitted at build time; runtime selection is deferred to a variant provider.
