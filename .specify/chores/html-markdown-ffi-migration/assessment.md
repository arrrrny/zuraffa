# Chore Assessment: Migrate html_to_markdown_ffi to be built on zuraffa

- **Slug**: html-markdown-ffi-migration
- **Created**: 2026-10-18
- **Source**: https://github.com/arrrrny/zuraffa/issues/687
- **Verdict**: in scope (large, multi-repo)
- **Size**: large

## Report (verbatim or summarized)

Issue #687 — "[v6] Migrate html_to_markdown_ffi to be built on zuraffa", a sub-issue of EPIC #214 ([v6] Migrate all ZikZak pub.dev packages to be built on zuraffa). Package: `html_to_markdown_ffi` (pub.dev). Goal: migrate the package's codebase to a complete rewrite on zuraffa per the EPIC #214 migration plan. Notes: platform implementations (android/windows/linux/macos) are covered by the umbrella `zikzak_inappwebview` package — do NOT create separate platform sub-issues. Labels: enhancement, v6, zuraffa_core, chore.

## Summary

This is a brownfield migration of the `html_to_markdown_ffi` plugin (currently published as a federated plugin: app-facing + platform + platform-adapter packages) onto the zuraffa v6 architecture as a **pure Dart package**. Per `docs/package_migration_guide.md` §1, FFI is not a platform channel, so an FFI-only package stays a pure package (`zfa package create`); a federated monorepo (`zfa package create-plugin`) is reserved for packages that talk to platform APIs/channels, which this one does not. Platform adapters are provisionally sourced from `zikzak_inappwebview` (FFI coverage on iOS/Android/Windows/Linux/macOS not yet confirmed); if any platform lacks the bridge, the migration plan — and Spec 064 — must include the missing native implementation so all five platforms stay covered. The adapter source stays provisional until coverage is verified. It is tracked in the zuraffa repo via spec `specs/064-migrate-html-to-markdown-ffi/` (Draft) and follows `docs/package_migration_guide.md`. The actual source rewrite lives in the `html_to_markdown_ffi` repository; in zuraffa the deliverable is the spec/assessment and any zuraffa-side capability gaps it surfaces.

## Constitution Check

- `.specify/memory/constitution.md` (if present) governs; migration must preserve the public API surface (FR-006 of spec 064) or document breaking changes. No new runtime dependencies should be added to zuraffa core for this package.
- Layer discipline: domain must not import `dart:ffi`/`dart:io`/channel code; the FFI bridge stays behind a port in the data layer.
- **Shape decision (guide §1)**: no channel wrappers are required — `html_to_markdown_ffi` is FFI-only, so the target shape is a pure Dart package (`zfa package create`), NOT a federated plugin (`zfa package create-plugin`). The FFI bridge is a datasource behind a port, not a platform adapter. Platform adapters are provisionally sourced from `zikzak_inappwebview` (coverage unconfirmed; see Open Questions) — not scaffolded here.

## Affected Paths

- `specs/064-migrate-html-to-markdown-ffi/spec.md` — migration spec (Draft). (No sibling migration spec in 053–065 ships a `tasks.md`, and only 058/065 carry a `tdd/` dir, so any `tasks.md`/`tdd/` artifacts added here would be new, not parity with siblings.)
- `docs/package_migration_guide.md` — canonical brownfield playbook (shape decision, mapping table, parity gates).
- External repo `arrrrny/html_to_markdown_ffi` — actual rewrite target (currently federated on pub.dev; target shape per §1 is a pure package).
- `lib/src/commands/package_command.dart` / `zfa package create` — scaffold entrypoint used for the pure-package shape. Federated `zfa package create-plugin` is NOT used (see §1 shape decision).

## Proposed Approach

**Preferred**: Follow the brownfield playbook end to end in the package repo:
1. Phase 0 inventory (public API, behavior, native, dependency, consumer census) -> `migration-contract.md`.
2. Phase 1 scaffold via `zfa package create html_to_markdown_ffi` (pure package; in-place rewrite if keeping the same repo). `zfa package create-plugin` is not used — FFI is not a platform channel (guide §1).
3. Phase 2 map old API to zuraffa shapes (Port + Service + UseCases; entities; AppFailure).
4. Phase 3 port tests first; wire `zfa tdd` engine for new behavior; keep test count >= baseline.
5. Phase 4 compatibility facade preserving public API.
6. Phase 5 parity gates (API, behavior, layer discipline, DI, statics, lifecycle, publish, journal).
7. Phase 6 publish as minor.

In zuraffa, optionally add `tasks.md` and `tdd/cycle-log.md` to spec 064 so the migration is trackable and auditable (these are new artifacts, not parity with siblings).

**Alternatives**:
- Treat as a "nothing to ship" tracking issue if the spec is considered the deliverable (rejected: issue is open and migration not executed).

**Paths likely to change**:
- `specs/064-migrate-html-to-markdown-ffi/tasks.md` (new, optional)
- `specs/064-migrate-html-to-markdown-ffi/tdd/cycle-log.md` (new, optional)
- External package repo (full rewrite)

**Verification to run**:
- In package repo: `dart pub get`, `dart analyze`, `dart test` (all green); `dart pub publish --dry-run` clean.
- In zuraffa: `dart test -j 2` remains green (no source changes here).

## Risks & Considerations

- Large blast radius: federated plugin with native libs; platform adapters must not be duplicated (FR-007, issue notes).
- Native bindings must be preserved verbatim (FR-003); FFI bridge wrapped by datasource, not replaced.
- Public API parity (FR-006) constrains the rewrite; facade layer required.
- Publishing/versioning: minor bump for facade-complete, major only when facades removed.
- Tracking-only change in zuraffa must not perturb the test suite or analysis.

## Open Questions

- [NEEDS CLARIFICATION: whether the rewrite lands in the existing `html_to_markdown_ffi` repo or a fresh zuraffa-namespaced repo per EPIC #214 rollout order]
- [NEEDS CLARIFICATION: whether `zikzak_inappwebview` already exposes the platform FFI for all five platforms; until confirmed the adapter source stays provisional and any missing platform must be added to the migration plan so Spec 064 covers all five platforms]
