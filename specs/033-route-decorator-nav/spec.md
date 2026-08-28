# Feature Specification: @Route Decorator for Auto-Generated Navigation Configuration

**Feature Branch**: `033-route-decorator-nav`

**Created**: 2026-08-28

**Status**: Draft

**Input**: User description: "[v6] Track 6.1 — @Route Decorator for Auto-Generated Navigation Configuration: Add an @Route decorator that produces auto-generated navigation configuration for v6. This feature originates from GitHub issue #187 (https://github.com/arrrrny/zuraffa/issues/187)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Route Registration via Annotation (Priority: P1)

As a Zuraffa developer, I want to annotate my View classes with `@Route(path: '/products/:id')` and have the route configuration automatically generated when I run `zfa build`, so that I never have to manually configure navigation routes.

**Why this priority**: This is the core value proposition — eliminating manual route configuration. Without this, every other navigation feature requires boilerplate. This delivers the foundational capability that all other stories build upon.

**Independent Test**: Can be fully tested by placing `@Route` on a single View class, running `zfa build`, and verifying the generated route configuration file contains the correct route entry. Delivers value by removing manual route config for that view.

**Acceptance Scenarios**:

1. **Given** a View class annotated with `@Route(path: '/products')`, **When** `zfa build` is executed, **Then** a route configuration file is generated containing a route for `/products` pointing to that View.
2. **Given** a View class with a typed path parameter `@Route(path: '/products/:id')`, **When** `zfa build` is executed, **Then** the generated route configuration extracts the `:id` parameter and makes it available to the controller.
3. **Given** a View class annotated with `@Route(path: '/home')`, **When** `zfa build` is run multiple times, **Then** the generated route file is idempotent — the output is identical across runs.
4. **Given** multiple View classes each annotated with different `@Route` paths, **When** `zfa build` is executed, **Then** all routes appear in a single generated configuration file.

---

### User Story 2 - URL Parameter Extraction (Priority: P1)

As a developer, I want path parameters like `:id` and query parameters to be automatically extracted from the URL and passed to the controller, so that I can access route parameters without manual parsing.

**Why this priority**: URL parameter extraction is essential for any real-world routing — detail pages, search, filtering all depend on it. This is a P1 because apps cannot function without it.

**Independent Test**: Can be tested by annotating a View with `@Route(path: '/items/:id')`, navigating to `/items/42`, and verifying the controller receives `id = '42'`.

**Acceptance Scenarios**:

1. **Given** a route annotated with `@Route(path: '/items/:id')`, **When** the user navigates to `/items/42`, **Then** the controller receives `id` with value `'42'` as a typed parameter.
2. **Given** a route annotated with `@Route(path: '/search')`, **When** the user navigates to `/search?q=dart`, **Then** the controller receives `q` with value `'dart'` as a query parameter.
3. **Given** a route with both path and query parameters, **When** the user navigates to `/users/7/settings?tab=profile`, **Then** the controller receives both `userId = '7'` and `tab = 'profile'`.

---

### User Story 3 - Redirect Rules (Priority: P2)

As a developer, I want to declare redirect rules using `@Route.redirect(from: '/old', to: '/new')`, so that old URLs automatically forward to updated routes without broken links.

**Why this priority**: Redirects are critical for maintaining backward compatibility during route evolution, but they are not needed for initial app functionality. P2 because apps can ship without redirects and add them later.

**Independent Test**: Can be tested by adding a `@Route.redirect(from: '/legacy', to: '/home')`, navigating to `/legacy`, and verifying the user lands on `/home`.

**Acceptance Scenarios**:

1. **Given** a redirect annotation `@Route.redirect(from: '/old-page', to: '/new-page')`, **When** a user navigates to `/old-page`, **Then** they are automatically redirected to `/new-page`.
2. **Given** a redirect annotation, **When** `zfa build` is executed, **Then** the redirect rule appears in the generated route configuration.

---

### User Story 4 - Nested Routes (Priority: P2)

As a developer, I want to organize routes into a parent-child hierarchy using shell routes, so that I can create layouts with shared UI (navigation bars, sidebars) across child routes.

**Why this priority**: Nested routes are needed for any app with persistent navigation chrome. They are P2 because simpler apps (single-page flows) can function without them, but most real apps need them.

**Independent Test**: Can be tested by annotating a parent shell View and child Views, running `zfa build`, and verifying the generated route tree nests child routes under the parent.

**Acceptance Scenarios**:

1. **Given** a parent View annotated with `@Route(path: '/dashboard', isShell: true)` and child Views annotated with `@Route(path: '/analytics', parent: 'dashboard')`, **When** `zfa build` is executed, **Then** the generated route tree nests `/analytics` under the `/dashboard` shell.
2. **Given** nested route annotations, **When** the user navigates to `/dashboard/analytics`, **Then** the parent shell View renders alongside the child View.

---

### User Story 5 - Route Guards / Middleware (Priority: P2)

As a developer, I want to protect routes with authentication or authorization guards using `@Route.middleware([AuthGuard])`, so that unauthenticated users cannot access protected screens.

**Why this priority**: Route guards are essential for security, but they depend on the core route generation working first. P2 because the auth system itself may be built in parallel, and without it, guards cannot be tested end-to-end.

**Independent Test**: Can be tested by annotating a View with `@Route.middleware([MockGuard])`, navigating to that route while the guard returns false, and verifying the user is redirected.

**Acceptance Scenarios**:

1. **Given** a route annotated with `@Route.middleware([AuthGuard])`, **When** an unauthenticated user navigates to that route, **Then** the guard intercepts and the user is redirected (e.g., to a login page).
2. **Given** a route annotated with `@Route.middleware([AuthGuard])`, **When** an authenticated user navigates to that route, **Then** the guard allows access and the View renders normally.

---

### User Story 6 - Deep Link Configuration (Priority: P3)

As a developer, I want to mark routes as deep-link-aware using `deepLinkAware: true`, so that the build system generates platform-specific deep link configuration for iOS universal links and Android app links.

**Why this priority**: Deep linking is important for marketing and sharing but is not required for core app functionality. P3 because it depends on platform-specific build tooling that may be developed later.

**Independent Test**: Can be tested by annotating a View with `@Route(path: '/share', deepLinkAware: true)`, running `zfa build`, and verifying platform deep link configuration files are generated.

**Acceptance Scenarios**:

1. **Given** a route annotated with `@Route(path: '/share', deepLinkAware: true)`, **When** `zfa build` is executed, **Then** iOS `apple-app-site-association` and Android `assetlinks.json` configurations include the route.
2. **Given** a route without `deepLinkAware`, **When** `zfa build` is executed, **Then** no deep link configuration is generated for that route.

---

### User Story 7 - Type-Safe Route Parameters (Priority: P3)

As a developer, I want the build system to generate a typed `RouteParams` class for each route, so that I get compile-time safety when accessing route parameters instead of stringly-typed maps.

**Why this priority**: Type safety improves developer experience and catches errors at compile time, but it is an enhancement over the basic parameter extraction. P3 because the untyped extraction still works.

**Independent Test**: Can be tested by annotating a View with typed parameters, running `zfa build`, and verifying the generated `RouteParams` class has correctly typed fields.

**Acceptance Scenarios**:

1. **Given** a route annotated with `@Route(path: '/users/:id')` where `:id` is typed as `int`, **When** `zfa build` is executed, **Then** a `RouteParams` class is generated with `final int id`.
2. **Given** a generated `RouteParams` class, **When** a developer accesses `params.id`, **Then** the value is available as the declared type without manual casting.

---

### Edge Cases

- What happens when two Views declare the same `@Route(path: ...)`? The system MUST detect duplicate paths at build time and emit a clear error listing both annotated classes.
- What happens when a child route references a non-existent parent route name? The system MUST fail with a descriptive error indicating the parent route was not found.
- What happens when a `@Route` annotation is placed on a class that is not a View? The system MUST emit a build-time warning or error, depending on strictness mode.
- What happens when `zfa build` runs but no `@Route` annotations exist in the project? The system MUST generate a valid (empty) route configuration file rather than failing.
- What happens when a route parameter type cannot be resolved (e.g., an unsupported type)? The system MUST emit a build-time error with the unsupported type name.
- What happens when a redirect target route does not exist? The system MUST emit a build-time error indicating the target route is undefined.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a `@Route` class annotation that accepts at minimum a `path` parameter (string) and optional parameters: `deepLinkAware` (boolean), `isShell` (boolean), `parent` (string), `middleware` (list of guard classes), and `redirect` configuration (`from`/`to` strings).
- **FR-002**: System MUST scan all `@Route` annotations during `zfa build` and compile them into a single route configuration file at a well-known path (e.g., `lib/src/routing/zfa_router.g.dart`).
- **FR-003**: System MUST extract URL path parameters (e.g., `:id`) from annotated route paths and make them available to the associated controller at initialization time.
- **FR-004**: System MUST support query parameter extraction from the URL and make them available to the controller.
- **FR-005**: System MUST generate redirect rules in the route configuration when `@Route.redirect(from: ..., to: ...)` annotations are present.
- **FR-006**: System MUST detect and report errors at build time for: duplicate route paths, missing parent routes, annotations on non-View classes, unsupported parameter types, and redirect targets that do not exist.
- **FR-007**: System MUST support nested route hierarchies by associating child routes with parent shell routes via the `parent` parameter.
- **FR-008**: System MUST wrap annotated routes with guard/middleware classes when `@Route.middleware([...])` is specified, invoking the guard before route activation.

### Key Entities

- **@Route Annotation**: A class-level annotation placed on View classes. Key attributes: `path` (route URL pattern), `deepLinkAware` (boolean for platform deep links), `isShell` (boolean for parent shell routes), `parent` (string linking to parent route name), `middleware` (list of guard classes), redirect configuration.
- **Route Configuration File**: The generated output file containing all compiled routes. This is the single source of truth for the app's navigation structure, replacing any manual route setup.
- **RouteParams Class**: A generated typed class per route containing all extracted path and query parameters as typed fields.
- **Route Guard**: A class implementing a guard interface that is invoked before a route activates. Receives the navigation context and returns whether navigation should proceed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can define a complete route for a new feature by adding a single `@Route` annotation to a View class, without writing any manual route configuration code.
- **SC-002**: `zfa build` generates a complete, valid route configuration file from `@Route` annotations in under 2 seconds for a project with up to 100 annotated Views.
- **SC-003**: All duplicate paths, missing parents, and invalid configurations are caught at build time with clear, actionable error messages — no silent runtime failures from route misconfiguration.
- **SC-004**: Generated route parameters are compile-time safe — a type mismatch between the annotated parameter type and the controller's expected type produces a build error, not a runtime crash.

## Assumptions

- Zuraffa v6 uses `package:go_router` as the default routing package. The generated route configuration file targets GoRouter's API.
- The annotation scanning infrastructure from Track 1.3 (DDA Foundation) is available and provides the compiler pipeline for reading Dart annotations at build time.
- View classes in Zuraffa v6 follow a convention where each View has an associated Controller, and the route system passes parameters to the Controller's initialization.
- The `@Route` annotation will be defined in a core Zuraffa package (e.g., `zuraffa_ui` or `zuraffa_core`) so it is available to all Views without additional imports.
- Deep link configuration (iOS universal links, Android app links) is generated as side-effect files alongside the route configuration, not as part of the Dart source.
- Route guards implement a standard interface (`ZuraffaRouteGuard` or equivalent) and are resolved via the DI container at runtime.
- This feature depends on the annotation scanning pipeline from Track 1.3 (DDA Foundation) being operational. If Track 1.3 is delayed, this feature's build-time scanning cannot function.
