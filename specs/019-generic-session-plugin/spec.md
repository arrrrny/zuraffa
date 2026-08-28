# Feature Specification: Generic Session Plugin

**Feature Branch**: `019-generic-session-plugin`

**Created**: 2026-08-23

**Status**: Draft

**Input**: User description: "Create a built in session plugin, this will be used both directly on zuraffa and zuraffa_flutter built apps it should be generic and a new dart package zikzak_session which will hold portable browser sessions will use this and base it. it should be able to hold any type of session with built in presets"

## Summary

Add a **built-in, generic session plugin** to the Zuraffa platform that lets any application hold and manage *any type of session* through a shared, platform-agnostic abstraction.

The plugin must be usable **directly** in pure-Dart `zuraffa` applications and in `zuraffa_flutter`-built (Flutter) applications through the *same* API. It ships with **built-in presets** for common session kinds so applications get working sessions with zero custom configuration, while still allowing fully custom session types.

A new separate Dart package, **`zikzak_session`**, will be built *on top of* this plugin. Its job is to provide **portable browser sessions** (cookies, headers, tokens) that can travel across platforms and devices — reusing the session plugin as its foundation rather than reimplementing session logic.

The core goal: one generic session model that serves both runtimes (pure Dart + Flutter) and any session domain, with ready-made presets and a dedicated browser-session layer.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generic session container with built-in presets (Priority: P1)

As an application developer building on either pure-Dart `zuraffa` or `zuraffa_flutter`, I want to add session management using a built-in preset (e.g., auth token, cookie, anonymous) so that my app can hold and use sessions without writing any session plumbing.

**Why this priority**: This is the foundational capability every other story depends on. Without a generic, preset-driven container usable in both runtimes, the feature has no value.

**Independent Test**: Can be fully tested by creating a new app, adding a session from a built-in preset, reading its value back, and clearing it — in both a pure-Dart and a Flutter context — and delivers working session storage with no custom session code.

**Acceptance Scenarios**:

1. **Given** a fresh application on `zuraffa` (pure Dart), **When** I create a session from the built-in `authToken` preset with a token value, **Then** the session is stored and I can retrieve the token value back.
2. **Given** a `zuraffa_flutter` application, **When** I perform the same preset-based session creation, **Then** the API and behavior are identical to the pure-Dart case.
3. **Given** any built-in preset, **When** I instantiate it, **Then** it works with zero custom configuration or schema definition.
4. **Given** a stored session, **When** I clear it, **Then** subsequent reads return empty / not-found.

---

### User Story 2 - Portable serialization across platforms (Priority: P2)

As a developer of `zikzak_session` (or any app), I want sessions to serialize to a portable format and deserialize identically on a different runtime, so that browser sessions (cookies, headers, tokens) can be carried between a server, a CLI, and a Flutter app.

**Why this priority**: Portability is the differentiating requirement that justifies a shared plugin and the separate `zikzak_session` package; without it the two runtimes would each need their own session code.

**Independent Test**: Can be fully tested by serializing a session in a pure-Dart context, transporting the bytes/string to a Flutter context, deserializing, and asserting the reconstructed session equals the original (round-trip fidelity).

**Acceptance Scenarios**:

1. **Given** an active session in a pure-Dart app, **When** I serialize it and deserialize it in a Flutter app, **Then** the reconstructed session has identical type, id, and payload.
2. **Given** a `zikzak_session` browser session (cookies + headers), **When** I serialize and port it to another device/runtime, **Then** the cookies and headers are restored exactly.
3. **Given** a malformed or unknown serialized session, **When** I attempt to deserialize it, **Then** the system reports a clear, recoverable error instead of crashing.

---

### User Story 3 - Custom session types, scoping, and persistence (Priority: P3)

As an advanced developer, I want to register my own session types/presets, keep multiple independent sessions isolated by scope, and optionally persist sessions across restarts — so the plugin fits domains beyond the built-ins.

**Why this priority**: Extensibility, multi-session isolation, and persistence are needed for real-world use but are not required for the core MVP (Stories 1–2).

**Independent Test**: Can be fully tested by registering a custom preset, creating two sessions under different scopes, verifying they do not leak into each other, and (with a persistence backend) verifying a session survives a restart.

**Acceptance Scenarios**:

1. **Given** a custom session type registered as a preset, **When** I create a session of that type, **Then** it behaves like a built-in preset.
2. **Given** two sessions created under scopes `A` and `B`, **When** I read scope `A`, **Then** I do not see scope `B`'s session data.
3. **Given** a persistence backend is configured, **When** the app restarts, **Then** previously stored sessions are available again.

---

### Edge Cases

- What happens when the session store is empty and a read is attempted? (must return not-found, not throw)
- How does the system handle a serialized session whose type/preset is not registered in the current runtime? (clear error, no crash)
- How are concurrent reads/writes to the same session handled? (safe, last-write-wins or guarded access)
- How are expired sessions treated when a preset defines expiry? (treated as invalid/not-found on access)
- What happens when serializing an unusually large session payload? (bounded, portable format; no silent truncation)
- What happens when a session is restored on a runtime that lacks a required field? (graceful defaults / explicit error)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a generic session container capable of holding *any* type of session data (typed objects or key-value) without requiring a predefined schema.
- **FR-002**: System MUST ship built-in presets for common session kinds (at minimum: anonymous, authentication token, cookie, header, OAuth, API key) that applications can instantiate with zero custom configuration.
- **FR-003**: Applications MUST be able to register custom session types/presets beyond the built-ins through a defined extension point.
- **FR-004**: The session plugin MUST be platform-agnostic — usable in pure-Dart `zuraffa` and in `zuraffa_flutter` applications with the same API and with no platform-specific (Flutter/UI) dependencies in its core.
- **FR-005**: System MUST support the full session lifecycle: create/store, retrieve, update, and clear.
- **FR-006**: System MUST support serialization to and deserialization from a portable, transferable format so sessions move across runtimes and devices.
- **FR-007**: System MUST support isolating multiple independent sessions via scoping/namespacing.
- **FR-008**: System SHOULD support optional persistence across application restarts through a pluggable storage backend (in-memory by default).
- **FR-009**: The separate `zikzak_session` package MUST be built on top of this plugin and MUST provide portable browser session capabilities (cookies, headers, tokens) by reusing the same preset/abstraction rather than reimplementing session logic.
- **FR-010**: System MUST expose a clean, extensible API surface that both application code and `zikzak_session` can consume and extend.

### Key Entities *(include if feature involves data)*

- **Session**: A unit of session state with a type identifier, unique id, payload (typed or key-value), metadata (created/updated, optional expiry), and serialization support.
- **SessionPreset**: A named, reusable definition/template for a common session kind. Built-ins are provided; applications may register custom ones.
- **SessionContainer / Store**: Holds and manages multiple sessions; provides CRUD, serialization, scoping/isolation, and (optionally) persistence.
- **PortableBrowserSession** (in `zikzak_session`): A specialization of a Session for browser contexts — carries cookies, headers, and tokens — portable across platforms and devices.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can add working session management to a new pure-Dart or Flutter app using a built-in preset in under 10 minutes, with no custom session code.
- **SC-002**: 100% of built-in presets are instantiable with zero configuration and pass their round-trip tests.
- **SC-003**: A session serialized in one runtime deserializes with 100% fidelity (type, id, payload) in a different runtime.
- **SC-004**: The session plugin core has zero platform-specific (Flutter/UI) dependencies, so it compiles and runs in a pure-Dart environment.
- **SC-005**: `zikzak_session` builds on the plugin and provides portable browser sessions while reusing (not duplicating) the core session logic.
- **SC-006**: At least 6 built-in presets (anonymous, auth token, cookie, header, OAuth, API key) are available and documented.

## Assumptions

- The session plugin lives in the `zuraffa` core (pure Dart) so both `zuraffa` and `zuraffa_flutter` (which re-exports `zuraffa`) can use it without duplication — consistent with the pure-Dart core split (spec #014).
- "Built-in" means the plugin ships as part of `zuraffa` and is always available by default (not an opt-in code-generator plugin).
- `zikzak_session` is a separate Dart package that depends on `zuraffa` and specializes in browser sessions; it reuses the session plugin foundation.
- Built-in presets include at least: anonymous, authentication token, cookie, header, OAuth, API key.
- Persistence is pluggable with an in-memory default; the choice of durable storage backend is left to the application.
- The portable serialization format is a standard, human-readable, transferable format (JSON-compatible).
- Relationship model: session plugin = generic foundation; `zikzak_session` = browser-session layer built on top.
- Concurrency is handled safely at the container level without requiring application-level locking for single sessions.
